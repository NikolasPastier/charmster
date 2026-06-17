import AVFoundation
import Foundation
import Observation

/// Per-beat, audio-first narrator for the lecture story player.
///
/// Audio-first by design: each beat's narration is played in the selected
/// coach's REAL voice, and the player advances when audio ends (or the user
/// taps).
///
/// Delivery strategy (hot-swappable, no rebuild needed to upgrade):
///  - PRIMARY: pre-generated per-(lecture, coach, beat) MP3 streamed from the
///    public `Avatars` bucket via `LectureAudioURL`. The recall beat plays two
///    clips in order (question, then "why" after answering).
///  - FALLBACK: offline `AVSpeechSynthesizer` tuned to the coach's `CoachStyle`
///    voice. Used when the MP3 is missing/unreachable so the experience stays
///    fully functional with the scripts + per-coach voices.
@Observable
final class LectureBeatNarrator: NSObject, AVSpeechSynthesizerDelegate {

  // MARK: - TTS fallback engine
  private let synth = AVSpeechSynthesizer()

  // MARK: - Remote MP3 engine
  private var player: AVPlayer?
  private var endObserver: NSObjectProtocol?
  private var timeObserver: Any?
  private var statusObservation: NSKeyValueObservation?

  /// Whether audio is currently playing (not paused, not finished).
  var isSpeaking: Bool = false
  /// 0..1 progress across the current beat's narration.
  var progress: Double = 0
  /// The beat id currently being narrated (nil when idle).
  private(set) var activeBeatId: String?

  // TTS progress tracking
  private var totalChars: Int = 1
  private var onFinished: (() -> Void)?
  private var didFinishNaturally = false

  // MP3 fallback context — kept so we can drop to TTS if streaming fails.
  private var fallbackText: String = ""
  private var fallbackStyle: CoachStyle = .wingman
  /// The exact remote URL of the clip currently being attempted, logged on any
  /// load failure so a genuine 404 is visible before the TTS fallback.
  private var currentRemoteURL: URL?

  override init() {
    super.init()
    synth.delegate = self
  }

  // MARK: - Public surface

  /// Speak a beat in the coach's voice. Plays the pre-generated MP3 when
  /// available, otherwise falls back to on-device TTS. `onComplete` fires once
  /// when the narration finishes naturally (used for auto-advance) — NOT on
  /// manual stop.
  ///
  /// For the recall beat this plays ONLY the question clip; reveal the answer
  /// then call `speakRecallWhy(...)` for the second clip.
  func speak(
    _ beat: LectureBeat,
    coach: CoachPersona,
    lecture: Lecture,
    onComplete: @escaping () -> Void
  ) {
    let segment: LectureAudioURL.Segment =
      beat.kind == .recallCheck ? .recallQuestion : .beat(beat.kind)
    start(
      beatId: beat.id,
      text: beat.narrationText,
      coach: coach,
      lecture: lecture,
      segment: segment,
      onComplete: onComplete)
  }

  /// Play the recall beat's "why" clip (after the user answers). Falls back to
  /// TTS of the recall reason when the MP3 is unavailable.
  func speakRecallWhy(
    _ beat: LectureBeat,
    coach: CoachPersona,
    lecture: Lecture,
    onComplete: @escaping () -> Void
  ) {
    let text = beat.recall?.why ?? beat.narrationText
    start(
      beatId: beat.id + "#why",
      text: text,
      coach: coach,
      lecture: lecture,
      segment: .recallWhy,
      onComplete: onComplete)
  }

  private func start(
    beatId: String,
    text: String,
    coach: CoachPersona,
    lecture: Lecture,
    segment: LectureAudioURL.Segment,
    onComplete: @escaping () -> Void
  ) {
    stop()
    activeBeatId = beatId
    onFinished = onComplete
    didFinishNaturally = false
    progress = 0
    fallbackText = text
    fallbackStyle = coach.style

    activateSession()

    if let url = LectureAudioURL.url(
      coachId: coach.id, trackId: lecture.trackId, number: lecture.number, segment: segment)
    {
      currentRemoteURL = url
      playRemote(url: url)
    } else {
      TenXPreviewSupport.log(
        "[LectureAudio] could not build URL (coach=\(coach.id) t\(lecture.trackId)-l\(lecture.number)) -> TTS"
      )
      speakWithTTS(text: text, style: coach.style)
    }
  }

  // MARK: - Remote MP3 playback

  private func playRemote(url: URL) {
    let item = AVPlayerItem(url: url)
    let player = AVPlayer(playerItem: item)
    self.player = player

    // Fall back to TTS if the item fails to load (404 / offline / bad asset).
    statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
      guard let self else { return }
      if item.status == .failed {
        let detail = item.error.map { " error=\($0.localizedDescription)" } ?? ""
        TenXPreviewSupport.log(
          "[LectureAudio] load FAILED url=\(self.currentRemoteURL?.absoluteString ?? "nil")\(detail) -> falling back to AVSpeechSynthesizer"
        )
        DispatchQueue.main.async { self.failoverToTTS() }
      }
    }

    // Progress across the clip.
    let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
    timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
      [weak self] time in
      guard let self, let item = self.player?.currentItem else { return }
      let dur = item.duration.seconds
      guard dur.isFinite, dur > 0 else { return }
      self.progress = min(1.0, max(0, time.seconds / dur))
    }

    endObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
    ) { [weak self] _ in
      self?.handleRemoteFinished()
    }

    isSpeaking = true
    player.play()
  }

  private func failoverToTTS() {
    // Tear down the failed player WITHOUT firing completion, then TTS-speak the
    // same text so the beat is never silent.
    teardownPlayer()
    speakWithTTS(text: fallbackText, style: fallbackStyle)
  }

  private func handleRemoteFinished() {
    progress = 1.0
    isSpeaking = false
    let handler = onFinished
    onFinished = nil
    teardownPlayer()
    activeBeatId = nil
    handler?()
  }

  private func teardownPlayer() {
    if let timeObserver, let player {
      player.removeTimeObserver(timeObserver)
    }
    timeObserver = nil
    statusObservation?.invalidate()
    statusObservation = nil
    if let endObserver {
      NotificationCenter.default.removeObserver(endObserver)
    }
    endObserver = nil
    player?.pause()
    player = nil
    currentRemoteURL = nil
  }

  // MARK: - TTS fallback

  private func speakWithTTS(text: String, style: CoachStyle) {
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(language: style.ttsVoiceLocale)
    utterance.rate = style.ttsRate
    utterance.pitchMultiplier = style.ttsPitch
    utterance.postUtteranceDelay = 0.05
    totalChars = max(1, text.count)
    isSpeaking = true
    synth.speak(utterance)
  }

  // MARK: - Pause / resume

  func pauseOrResume() {
    if let player {
      if isSpeaking {
        player.pause()
        isSpeaking = false
      } else {
        player.play()
        isSpeaking = true
      }
      return
    }
    if synth.isPaused {
      synth.continueSpeaking()
      isSpeaking = true
    } else if synth.isSpeaking {
      synth.pauseSpeaking(at: .word)
      isSpeaking = false
    }
  }

  func pause() {
    if let player {
      player.pause()
      isSpeaking = false
      return
    }
    if synth.isSpeaking, !synth.isPaused {
      synth.pauseSpeaking(at: .word)
      isSpeaking = false
    }
  }

  func resume() {
    if let player {
      player.play()
      isSpeaking = true
      return
    }
    if synth.isPaused {
      synth.continueSpeaking()
      isSpeaking = true
    }
  }

  /// Stop playback WITHOUT firing the completion handler (manual advance/skip).
  func stop() {
    onFinished = nil
    teardownPlayer()
    if synth.isSpeaking || synth.isPaused {
      synth.stopSpeaking(at: .immediate)
    }
    isSpeaking = false
    progress = 0
    activeBeatId = nil
  }

  // MARK: - Audio session

  private func activateSession() {
    #if os(iOS)
      let session = AVAudioSession.sharedInstance()
      try? session.setCategory(.playback, mode: .spokenAudio, options: [])
      try? session.setActive(true)
    #endif
  }

  // MARK: - TTS delegate

  func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart u: AVSpeechUtterance) {
    isSpeaking = true
  }

  func speechSynthesizer(
    _ s: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange,
    utterance: AVSpeechUtterance
  ) {
    let spoken = characterRange.location + characterRange.length
    progress = min(1.0, Double(spoken) / Double(totalChars))
  }

  func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
    isSpeaking = false
    progress = 1.0
    let handler = onFinished
    onFinished = nil
    activeBeatId = nil
    handler?()
  }

  func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) {
    isSpeaking = false
  }

  func speechSynthesizer(_ s: AVSpeechSynthesizer, didPause u: AVSpeechUtterance) {
    isSpeaking = false
  }

  func speechSynthesizer(_ s: AVSpeechSynthesizer, didContinue u: AVSpeechUtterance) {
    isSpeaking = true
  }
}
