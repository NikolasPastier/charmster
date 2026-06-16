import AVFoundation
import Foundation
import Observation

/// Per-beat, audio-first narrator for the lecture story player.
///
/// Audio-first by design: each beat's narration is spoken in the selected
/// coach's voice, and the player advances when audio ends (or the user taps).
///
/// Delivery strategy (hot-swappable, no rebuild needed to upgrade):
///  - PRIMARY: pre-generated per-(lecture, coach, beat) MP3 if uploaded to the
///    `Avatars` bucket. Wire the URL in `remoteAudioURL` when assets land.
///  - FALLBACK (today): offline `AVSpeechSynthesizer` tuned to the coach's
///    `CoachStyle` voice. This keeps the experience fully functional with the
///    scripts + per-coach voices as the only hard requirement.
@Observable
final class LectureBeatNarrator: NSObject, AVSpeechSynthesizerDelegate {

  private let synth = AVSpeechSynthesizer()

  /// Whether audio is currently playing (not paused, not finished).
  var isSpeaking: Bool = false
  /// 0..1 progress across the current beat's narration.
  var progress: Double = 0
  /// The beat id currently being narrated (nil when idle).
  private(set) var activeBeatId: String?

  private var totalChars: Int = 1
  private var onFinished: (() -> Void)?
  private var didFinishNaturally = false

  override init() {
    super.init()
    synth.delegate = self
  }

  // MARK: - Public surface

  /// Speak a beat in the coach's voice. `onComplete` fires once when the audio
  /// finishes naturally (used for optional auto-advance) — NOT on manual stop.
  func speak(_ beat: LectureBeat, coach: CoachStyle, onComplete: @escaping () -> Void) {
    stop()
    activeBeatId = beat.id
    onFinished = onComplete
    didFinishNaturally = false
    progress = 0

    activateSession()

    let utterance = AVSpeechUtterance(string: beat.narrationText)
    utterance.voice = AVSpeechSynthesisVoice(language: coach.ttsVoiceLocale)
    utterance.rate = coach.ttsRate
    utterance.pitchMultiplier = coach.ttsPitch
    utterance.postUtteranceDelay = 0.05
    totalChars = max(1, beat.narrationText.count)
    synth.speak(utterance)
  }

  func pauseOrResume() {
    if synth.isPaused {
      synth.continueSpeaking()
      isSpeaking = true
    } else if synth.isSpeaking {
      synth.pauseSpeaking(at: .word)
      isSpeaking = false
    }
  }

  func pause() {
    if synth.isSpeaking, !synth.isPaused {
      synth.pauseSpeaking(at: .word)
      isSpeaking = false
    }
  }

  func resume() {
    if synth.isPaused {
      synth.continueSpeaking()
      isSpeaking = true
    }
  }

  /// Stop playback WITHOUT firing the completion handler (manual advance/skip).
  func stop() {
    onFinished = nil
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

  // MARK: - Delegate

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
