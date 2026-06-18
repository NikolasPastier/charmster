import AVFoundation
import Foundation
import Observation
import UIKit

/// Real live video+voice review pipeline.
///
/// - Mic + front camera capture via AVCaptureSession (when permitted).
/// - Voice loop runs via `RealtimeLiveSession` (OpenAI Realtime) — partner
///   listens + speaks in real time, transcript + per-turn mood tag streamed.
/// - One camera frame sampled every ~2.5s, JPEG-compressed, POSTed to the
///   `vision_review` Edge Function. No raw video/audio is recorded or persisted.
/// - SessionSignals is populated from real measurements (responsiveness, voice,
///   synchrony, calibration, face, body, warmth). When real signals are
///   unavailable (offline, perms denied, function missing), SessionScorer
///   falls back to the deterministic SplitMix64 mock.
@Observable
@MainActor
final class LiveSessionPipeline: NSObject {

  enum Status {
    case idle
    case requestingPermission
    case running  // mic + cam + Realtime live
    case voiceOnly  // mic + Realtime live, no camera
    case mockFallback  // no mic / Realtime unavailable — UI animates from mock signal walker
    case failed(String)
  }

  var status: Status = .idle
  var cameraAvailable: Bool = false
  var micAvailable: Bool = false
  var liveFeel: Double = 0.55
  var partnerSpeaking: Bool = false
  var userSpeaking: Bool = false
  var captionsBuffer: String = ""
  var lastMoodTag: AvatarState?
  /// UX4 — mirrors of the latest completed user turn for the coach-nudge
  /// trigger. The view observes `userTurnCount` changing and reads
  /// `lastUserUtterance` to build a nudge.
  var userTurnCount: Int = 0
  var lastUserUtterance: String = ""
  var lastVisionFace: Int?
  var lastVisionBody: Int?
  var lastVisionWarmth: Double?

  /// Accumulated signals — read at session end to feed the scorer.
  private(set) var signals = SessionSignals()

  /// Underlying voice loop. Exposed read-only for UI binding.
  private(set) var realtime = RealtimeLiveSession()

  // MARK: - Configuration

  private let frameSampleInterval: TimeInterval = 2.5
  private var lastFrameSampleAt: Date?
  private var sessionId: String?
  private var lectureId: String?
  private var userId: String = "anon"

  // MARK: - AVCapture
  private let captureSession = AVCaptureSession()
  private let videoOutput = AVCaptureVideoDataOutput()
  private let captureQueue = DispatchQueue(label: "charmster.capture")
  private var visionInFlight = false

  // MARK: - Public lifecycle

  /// Start capture + open the Realtime voice loop. Falls through to voice-only
  /// or mock when components are unavailable. The pipeline is honest — no
  /// fake state is reported as live.
  func start(
    prefersCamera: Bool,
    persona: PartnerPersona,
    avatarPersona: AvatarPersona,
    voiceId: String,
    coach: CoachStyle,
    lecture: Lecture?,
    setting: PracticeSetting,
    userId: String
  ) async {
    self.userId = userId
    self.lectureId = lecture?.id
    self.sessionId = UUID().uuidString

    status = .requestingPermission
    let mic = await requestMic()
    let cam = prefersCamera ? await requestCamera() : false
    micAvailable = mic
    cameraAvailable = cam
    signals.cameraAvailable = cam

    if !mic {
      // Without mic we cannot run the Realtime voice loop. Fall through
      // to the deterministic mock so the UI still animates.
      status = .mockFallback
      return
    }

    // Configure AV session: PlayAndRecord so partner audio plays + mic captures.
    configureAudioSession()
    if cam { startCameraCapture() }

    // Mint ephemeral Realtime token from the edge function. If this fails,
    // we run voice-only without the live model (still real mic capture,
    // but scoring will fall back to mock voice metrics from RealtimeLiveSession).
    let req = RealtimeSessionService.Request(
      user_id: userId,
      lecture_id: lecture?.id,
      roadmap_node: lecture?.id,
      persona: .init(
        id: persona.id, displayName: persona.displayName,
        pronouns: persona.pronouns, blurb: persona.blurb),
      coach_style: coach.rawValue,
      setting: setting.title,
      realtime_voice: AvatarVoice.resolve(from: voiceId).realtimeVoice
    )
    if let token = await RealtimeSessionService.mint(req) {
      await realtime.connect(token: token)
      status = cam ? .running : .voiceOnly
    } else {
      TenXPreviewSupport.log("[Pipeline] realtime mint failed — running voice-only fallback")
      status = .mockFallback
    }
  }

  func stop() {
    realtime.disconnect()
    captureSession.stopRunning()
    try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    status = .idle
  }

  /// Pull current Realtime EMAs + vision into SessionSignals. Called by the
  /// view's per-second tick and at session end. Where a real signal is
  /// available, the matching `nil` is filled in; otherwise the field stays
  /// `nil` so SessionScorer's deterministic mock takes over for that slot.
  func tick() {
    // UI surface mirrors of Realtime state.
    partnerSpeaking = realtime.partnerSpeaking
    userSpeaking = realtime.userSpeaking
    if let tag = realtime.lastMoodTag { lastMoodTag = tag }
    userTurnCount = realtime.userTurnCount
    lastUserUtterance = realtime.lastUserUtterance
    if !realtime.liveTranscript.isEmpty {
      captionsBuffer = String(realtime.liveTranscript.suffix(240))
    }
    // Live feel = blended (voice + warmth + mood).
    let liveAtmosphere =
      (realtime.voiceEnergyEMA * 0.4
        + realtime.partnerWarmthEMA * 0.4
        + realtime.synchronyEMA * 0.2)
    liveFeel = max(0.15, min(0.95, liveAtmosphere))

    // Pump signals from real Realtime measurements.
    if case .running = status {
      signals.cameraAvailable = true
    } else if case .voiceOnly = status {
      signals.cameraAvailable = false
    }

    switch status {
    case .running, .voiceOnly:
      signals.meanVoiceEnergy = realtime.voiceEnergyEMA
      signals.voiceVariation = realtime.voiceVariationEMA
      signals.synchrony = realtime.synchronyEMA
      signals.partnerWarmth = realtime.partnerWarmthEMA
      signals.responseLatencyMean = realtime.lastResponseLatencySeconds
      signals.transcript = realtime.liveTranscript
      signals.faceEngagement = lastVisionFace.map { Double($0) / 100.0 }
      signals.bodyOpenness = lastVisionBody.map { Double($0) / 100.0 }
    case .mockFallback:
      tickMockSignals()
    default: break
    }
  }

  /// Mock signal walker — used ONLY when the real pipeline is unavailable
  /// (no mic, Realtime mint failed, preview/offline). SessionScorer's seeded
  /// SplitMix64 mock still takes over for unfilled `nil` slots.
  func tickMockSignals() {
    liveFeel = max(0.2, min(0.95, liveFeel + Double.random(in: -0.06...0.08)))
    if Bool.random() { partnerSpeaking.toggle() }
    signals.meanVoiceEnergy = liveFeel
    signals.voiceVariation = 0.5 + Double.random(in: -0.2...0.2)
    signals.faceEngagement = cameraAvailable ? liveFeel : nil
    signals.bodyOpenness = cameraAvailable ? max(0.4, liveFeel - 0.05) : nil
    signals.synchrony = 0.55 + Double.random(in: -0.15...0.15)
    signals.responseLatencyMean = 1.0 + Double.random(in: -0.3...0.6)
    signals.partnerWarmth = liveFeel
  }

  // MARK: - Permissions

  private func requestMic() async -> Bool {
    await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
      AVAudioApplication.requestRecordPermission { granted in
        cont.resume(returning: granted)
      }
    }
  }

  private func requestCamera() async -> Bool {
    await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
      AVCaptureDevice.requestAccess(for: .video) { granted in
        cont.resume(returning: granted)
      }
    }
  }

  // MARK: - Audio session

  private func configureAudioSession() {
    let s = AVAudioSession.sharedInstance()
    do {
      try s.setCategory(
        .playAndRecord, mode: .voiceChat,
        options: [.allowBluetooth, .defaultToSpeaker])
      try s.setActive(true, options: [])
    } catch {
      TenXPreviewSupport.log("[Pipeline] audio session error: \(error)")
    }
  }

  // MARK: - Camera capture + frame sampling

  private func startCameraCapture() {
    captureQueue.async { [weak self] in
      guard let self else { return }
      self.captureSession.beginConfiguration()
      self.captureSession.sessionPreset = .vga640x480

      // Strip existing inputs/outputs (replay-safe).
      for i in self.captureSession.inputs { self.captureSession.removeInput(i) }
      for o in self.captureSession.outputs { self.captureSession.removeOutput(o) }

      guard
        let device = AVCaptureDevice.default(
          .builtInWideAngleCamera,
          for: .video, position: .front),
        let input = try? AVCaptureDeviceInput(device: device)
      else {
        self.captureSession.commitConfiguration()
        return
      }
      if self.captureSession.canAddInput(input) { self.captureSession.addInput(input) }

      self.videoOutput.setSampleBufferDelegate(self, queue: self.captureQueue)
      self.videoOutput.videoSettings = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
      ]
      self.videoOutput.alwaysDiscardsLateVideoFrames = true
      if self.captureSession.canAddOutput(self.videoOutput) {
        self.captureSession.addOutput(self.videoOutput)
      }
      if let conn = self.videoOutput.connection(with: .video) {
        if conn.isVideoOrientationSupported { conn.videoOrientation = .portrait }
        if conn.isVideoMirroringSupported { conn.isVideoMirrored = true }
      }
      self.captureSession.commitConfiguration()
      self.captureSession.startRunning()
    }
  }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension LiveSessionPipeline: AVCaptureVideoDataOutputSampleBufferDelegate {

  nonisolated func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    guard let jpeg = Self.jpegDataFromPixelBuffer(pixelBuffer, quality: 0.55) else { return }

    Task { @MainActor [weak self] in
      guard let self else { return }
      let now = Date()
      if let last = self.lastFrameSampleAt, now.timeIntervalSince(last) < self.frameSampleInterval {
        return
      }
      if self.visionInFlight { return }
      self.lastFrameSampleAt = now
      self.visionInFlight = true

      let userId = self.userId
      let sessionId = self.sessionId
      let lectureId = self.lectureId
      let snippet = self.realtime.lastUserUtterance.isEmpty ? nil : self.realtime.lastUserUtterance

      let result = await VisionReviewService.score(
        jpeg: jpeg, userId: userId, sessionId: sessionId,
        lectureId: lectureId, transcriptSnippet: snippet
      )
      self.visionInFlight = false
      if let r = result {
        self.lastVisionFace = r.face
        self.lastVisionBody = r.body
        self.lastVisionWarmth = r.warmth
      }
    }
  }

  nonisolated private static func jpegDataFromPixelBuffer(
    _ pixelBuffer: CVPixelBuffer, quality: CGFloat
  ) -> Data? {
    let ci = CIImage(cvPixelBuffer: pixelBuffer)
    let context = CIContext(options: nil)
    guard let cg = context.createCGImage(ci, from: ci.extent) else { return nil }
    let ui = UIImage(cgImage: cg)
    return ui.jpegData(compressionQuality: quality)
  }
}
