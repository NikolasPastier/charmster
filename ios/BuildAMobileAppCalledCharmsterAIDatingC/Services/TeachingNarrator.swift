import Foundation
import AVFoundation
import Observation

/// Offline AVSpeechSynthesizer narrator used by the teaching screen.
/// Production swaps this for OpenAI TTS streamed from a Supabase edge function.
@Observable
final class TeachingNarrator: NSObject, AVSpeechSynthesizerDelegate {
    private let synth = AVSpeechSynthesizer()
    var isSpeaking: Bool = false
    var progress: Double = 0          // 0..1 across the script
    private var totalChars: Int = 1
    private var spokenChars: Int = 0

    override init() {
        super.init()
        synth.delegate = self
    }

    func speak(_ text: String, coach: CoachStyle) {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: coach.ttsVoiceLocale)
        utterance.rate = coach.ttsRate
        utterance.pitchMultiplier = coach.ttsPitch
        utterance.postUtteranceDelay = 0.1
        totalChars = max(1, text.count)
        spokenChars = 0
        synth.speak(utterance)
    }

    func pauseOrResume() {
        if synth.isPaused {
            synth.continueSpeaking()
        } else if synth.isSpeaking {
            synth.pauseSpeaking(at: .word)
        }
    }

    func stop() {
        if synth.isSpeaking || synth.isPaused {
            synth.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        progress = 0
    }

    // MARK: - Delegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        isSpeaking = true
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        spokenChars = characterRange.location + characterRange.length
        progress = min(1.0, Double(spokenChars) / Double(totalChars))
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
        progress = 1.0
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        isSpeaking = true
    }
}
