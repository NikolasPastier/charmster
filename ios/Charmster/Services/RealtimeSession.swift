import AVFoundation
import Foundation
import Observation

/// Thin client for the Supabase `realtime_session` Edge Function. Mints an
/// ephemeral OpenAI Realtime session token server-side so the real
/// OPENAI_API_KEY never touches the device.
struct RealtimeSessionService {

  struct Token: Decodable {
    let clientSecret: String
    let expiresAt: Int?
    let model: String?
    let voice: String?
    let sessionId: String?

    enum CodingKeys: String, CodingKey {
      case clientSecret = "client_secret"
      case expiresAt = "expires_at"
      case model
      case voice
      case sessionId = "session_id"
    }
  }

  struct Request: Encodable {
    let user_id: String
    let lecture_id: String?
    let roadmap_node: String?
    let persona: PersonaPayload
    let coach_style: String
    let setting: String
    /// Closest OpenAI Realtime voice for the partner (Route A). The edge
    /// function uses this when minting the session so the partner speaks in the
    /// user's chosen voice. Optional so older callers stay valid.
    let realtime_voice: String?
    let focus_skills: [String]?

    struct PersonaPayload: Encodable {
      let id: String
      let displayName: String
      let pronouns: String
      let blurb: String
    }
  }

  static var baseURL: URL? {
    let env = ProcessInfo.processInfo.environment["SUPABASE_URL"]
    let base = (env?.isEmpty == false ? env! : "https://uvjtrhvhldeeslgnvhyd.supabase.co")
      .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    return URL(string: "\(base)/functions/v1/realtime_session")
  }

  static var anonKey: String? {
    let env = ProcessInfo.processInfo.environment
    return env["SUPABASE_PUBLISHABLE_KEY"] ?? env["SUPABASE_ANON_KEY"]
  }

  /// Mint a short-lived Realtime session token. Returns nil on any failure
  /// (caller falls back to voice-only or mock).
  static func mint(_ req: Request) async -> Token? {
    guard let url = baseURL, let key = anonKey else { return nil }
    var r = URLRequest(url: url)
    r.httpMethod = "POST"
    r.setValue("application/json", forHTTPHeaderField: "Content-Type")
    r.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
    r.setValue(key, forHTTPHeaderField: "apikey")
    r.httpBody = try? JSONEncoder().encode(req)
    do {
      let (data, resp) = try await URLSession.shared.data(for: r)
      guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        return nil
      }
      return try JSONDecoder().decode(Token.self, from: data)
    } catch {
      return nil
    }
  }
}

// MARK: - Realtime live session

/// Maintains the live Realtime conversation: opens the WebSocket using the
/// ephemeral token from `realtime_session`, streams mic audio up, decodes
/// partner audio down, and surfaces transcript + per-turn mood tags.
///
/// Honest scope: WebRTC isn't available without a third-party package, so this
/// uses OpenAI's documented WebSocket transport (same Realtime API). Mic audio
/// is sent as base64 PCM16; partner audio is rendered through an AVAudioEngine
/// player node. Lip-sync is intentionally generic (the `talking` clip is a
/// loop) per spec.
@Observable
@MainActor
final class RealtimeLiveSession: NSObject {

  enum Status {
    case idle, connecting, live, ended
    case failed(String)
  }

  private(set) var status: Status = .idle
  private(set) var partnerSpeaking: Bool = false
  private(set) var userSpeaking: Bool = false
  private(set) var liveTranscript: String = ""
  private(set) var lastUserUtterance: String = ""
  /// Monotonic count of COMPLETED user turns (transcribed utterances). Drives
  /// the UX4 coach-nudge trigger — the view observes this changing.
  private(set) var userTurnCount: Int = 0
  private(set) var lastMoodTag: AvatarState?
  private(set) var turnsTaken: Int = 0
  private(set) var lastResponseLatencySeconds: Double?

  /// Rolling responsiveness/synchrony estimators (0..1).
  private(set) var responsivenessEMA: Double = 0.5
  private(set) var synchronyEMA: Double = 0.5
  private(set) var voiceEnergyEMA: Double = 0.5
  private(set) var voiceVariationEMA: Double = 0.5
  private(set) var partnerWarmthEMA: Double = 0.5

  private var task: URLSessionWebSocketTask?
  private var session: URLSession?
  private var audioEngine: AVAudioEngine?
  private var playerNode: AVAudioPlayerNode?
  private var outputFormat: AVAudioFormat?
  private var inputFormat: AVAudioFormat?
  private var pcmConverter: AVAudioConverter?

  private var userTurnStartedAt: Date?
  private var partnerTurnRequestedAt: Date?
  private var lastResponseEnergies: [Double] = []
  private var lastUserEnergies: [Double] = []

  /// Connect to OpenAI Realtime using a freshly-minted ephemeral token. The
  /// session sends `instructions` already baked in by `realtime_session`.
  func connect(token: RealtimeSessionService.Token) async {
    status = .connecting

    guard let secret = Optional(token.clientSecret), !secret.isEmpty else {
      status = .failed("missing client_secret")
      return
    }
    let model = token.model ?? "gpt-realtime-mini"
    guard let url = URL(string: "wss://api.openai.com/v1/realtime?model=\(model)") else {
      status = .failed("bad url")
      return
    }

    var req = URLRequest(url: url)
    req.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
    req.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")

    let sess = URLSession(configuration: .default)
    self.session = sess
    let t = sess.webSocketTask(with: req)
    self.task = t
    t.resume()

    startAudio()
    receiveLoop()
    status = .live
    TenXPreviewSupport.log("[Realtime] connected")
  }

  func disconnect() {
    TenXPreviewSupport.log("[Realtime] disconnect")
    task?.cancel(with: .goingAway, reason: nil)
    task = nil
    stopAudio()
    status = .ended
  }

  // MARK: - Audio plumbing

  private func startAudio() {
    let engine = AVAudioEngine()
    let player = AVAudioPlayerNode()
    engine.attach(player)
    let outFmt = AVAudioFormat(
      commonFormat: .pcmFormatInt16, sampleRate: 24_000,
      channels: 1, interleaved: true)!
    engine.connect(player, to: engine.mainMixerNode, format: outFmt)

    // Mic input -> PCM16 24kHz mono -> WebSocket
    let inputNode = engine.inputNode
    let inFmt = inputNode.inputFormat(forBus: 0)
    self.inputFormat = inFmt
    self.outputFormat = outFmt
    self.pcmConverter = AVAudioConverter(from: inFmt, to: outFmt)

    inputNode.installTap(onBus: 0, bufferSize: 2048, format: inFmt) { [weak self] buf, _ in
      self?.handleMicBuffer(buf)
    }

    do {
      try engine.start()
      player.play()
      self.audioEngine = engine
      self.playerNode = player
    } catch {
      TenXPreviewSupport.log("[Realtime] audio engine failed: \(error)")
    }
  }

  private func stopAudio() {
    audioEngine?.inputNode.removeTap(onBus: 0)
    playerNode?.stop()
    audioEngine?.stop()
    playerNode = nil
    audioEngine = nil
  }

  private func handleMicBuffer(_ buf: AVAudioPCMBuffer) {
    guard let converter = pcmConverter, let outFmt = outputFormat else { return }
    let outCapacity =
      AVAudioFrameCount(Double(buf.frameLength) * outFmt.sampleRate / buf.format.sampleRate) + 1024
    guard let outBuf = AVAudioPCMBuffer(pcmFormat: outFmt, frameCapacity: outCapacity) else {
      return
    }

    var err: NSError?
    var supplied = false
    converter.convert(to: outBuf, error: &err) { _, status in
      if supplied {
        status.pointee = .noDataNow
        return nil
      }
      supplied = true
      status.pointee = .haveData
      return buf
    }
    if err != nil { return }

    // Voice energy (RMS) for prosody EMAs + simple VAD.
    let rms = rmsLevel(buf)
    let isVoice = rms > 0.02
    let prev = userSpeaking
    userSpeaking = isVoice
    if isVoice && !prev {
      userTurnStartedAt = Date()
      partnerSpeaking = false
    }
    voiceEnergyEMA = blend(voiceEnergyEMA, rms.normalized)
    lastUserEnergies.append(rms)
    if lastUserEnergies.count > 64 { lastUserEnergies.removeFirst(lastUserEnergies.count - 64) }
    voiceVariationEMA = blend(voiceVariationEMA, stddev(lastUserEnergies).normalized)

    // PCM16 -> base64 -> append to model input buffer.
    guard let ch = outBuf.int16ChannelData else { return }
    let count = Int(outBuf.frameLength)
    let data = Data(bytes: ch[0], count: count * MemoryLayout<Int16>.size)
    let b64 = data.base64EncodedString()
    sendJSON([
      "type": "input_audio_buffer.append",
      "audio": b64,
    ])
  }

  // MARK: - Send / receive

  private func sendJSON(_ obj: [String: Any]) {
    guard let task else { return }
    guard let data = try? JSONSerialization.data(withJSONObject: obj),
      let str = String(data: data, encoding: .utf8)
    else { return }
    task.send(.string(str)) { err in
      if let err { TenXPreviewSupport.log("[Realtime] send failed: \(err)") }
    }
  }

  private func receiveLoop() {
    guard let task else { return }
    task.receive { [weak self] result in
      guard let self else { return }
      Task { @MainActor in
        switch result {
        case .failure(let err):
          self.status = .failed("ws: \(err.localizedDescription)")
          return
        case .success(let msg):
          self.handleIncoming(msg)
          self.receiveLoop()
        }
      }
    }
  }

  private func handleIncoming(_ msg: URLSessionWebSocketTask.Message) {
    switch msg {
    case .string(let s):
      handleEventString(s)
    case .data(let d):
      if let s = String(data: d, encoding: .utf8) { handleEventString(s) }
    @unknown default: break
    }
  }

  private func handleEventString(_ s: String) {
    guard let data = s.data(using: .utf8),
      let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
      let type = obj["type"] as? String
    else { return }

    switch type {
    case "response.audio.delta":
      if let b64 = obj["delta"] as? String, let pcm = Data(base64Encoded: b64) {
        enqueuePartnerAudio(pcm)
        partnerSpeaking = true
        partnerTurnRequestedAt = partnerTurnRequestedAt ?? Date()
      }
    case "response.audio.done", "response.done":
      partnerSpeaking = false
      turnsTaken += 1
      if let start = partnerTurnRequestedAt, let utter = userTurnStartedAt {
        lastResponseLatencySeconds = start.timeIntervalSince(utter)
        let resp = 1.0 - min((lastResponseLatencySeconds ?? 1.0) / 4.0, 1.0)
        responsivenessEMA = blend(responsivenessEMA, resp)
      }
      partnerTurnRequestedAt = nil
      userTurnStartedAt = nil
    case "response.audio_transcript.delta":
      if let delta = obj["delta"] as? String {
        liveTranscript += delta
      }
    case "conversation.item.input_audio_transcription.completed":
      if let text = obj["transcript"] as? String {
        lastUserUtterance = text
        liveTranscript += "\nYou: \(text)\n"
        userTurnCount += 1
      }
    case "response.function_call_arguments.done":
      if let name = obj["name"] as? String, name == "set_mood",
        let argStr = obj["arguments"] as? String,
        let argData = argStr.data(using: .utf8),
        let args = (try? JSONSerialization.jsonObject(with: argData)) as? [String: Any],
        let mood = args["mood"] as? String,
        let state = AvatarState.fromMoodTag(mood)
      {
        lastMoodTag = state
        // Mood diversity + warmth proxy.
        let warmth: Double
        switch state {
        case .smile, .laugh, .flirty, .reassure: warmth = 0.85
        case .cool, .listening, .thinking: warmth = 0.6
        case .surprised: warmth = 0.55
        default: warmth = 0.5
        }
        partnerWarmthEMA = blend(partnerWarmthEMA, warmth)
        // Synchrony: did the partner's mood track the user energy?
        let sync = max(0, 1.0 - abs(voiceEnergyEMA - warmth))
        synchronyEMA = blend(synchronyEMA, sync)
      }
    case "error":
      TenXPreviewSupport.log("[Realtime] error event: \(obj)")
    default: break
    }
  }

  private func enqueuePartnerAudio(_ pcm: Data) {
    guard let player = playerNode, let fmt = outputFormat else { return }
    let frameCount = AVAudioFrameCount(pcm.count / MemoryLayout<Int16>.size)
    guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frameCount) else { return }
    buf.frameLength = frameCount
    pcm.withUnsafeBytes { raw in
      guard let src = raw.baseAddress, let dst = buf.int16ChannelData?[0] else { return }
      memcpy(dst, src, pcm.count)
    }
    // Track partner energy for warmth proxy.
    let rms = rmsLevel(buf)
    lastResponseEnergies.append(rms)
    if lastResponseEnergies.count > 64 {
      lastResponseEnergies.removeFirst(lastResponseEnergies.count - 64)
    }
    player.scheduleBuffer(buf, completionHandler: nil)
    if !player.isPlaying { player.play() }
  }

  // MARK: - Utility

  private func rmsLevel(_ buf: AVAudioPCMBuffer) -> Double {
    let count = Int(buf.frameLength)
    guard count > 0 else { return 0 }
    var sumSq: Double = 0
    if let ch = buf.floatChannelData {
      let p = ch[0]
      for i in 0..<count {
        let v = Double(p[i])
        sumSq += v * v
      }
    } else if let ch = buf.int16ChannelData {
      let p = ch[0]
      for i in 0..<count {
        let v = Double(p[i]) / 32768.0
        sumSq += v * v
      }
    }
    return (sumSq / Double(count)).squareRoot()
  }

  private func stddev(_ xs: [Double]) -> Double {
    guard xs.count > 1 else { return 0 }
    let mean = xs.reduce(0, +) / Double(xs.count)
    let v = xs.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(xs.count)
    return v.squareRoot()
  }

  private func blend(_ ema: Double, _ x: Double, alpha: Double = 0.2) -> Double {
    ema * (1 - alpha) + x * alpha
  }
}

extension Double {
  /// Squash an RMS-like value into 0..1.
  fileprivate var normalized: Double { max(0, min(1, self * 6)) }
}
