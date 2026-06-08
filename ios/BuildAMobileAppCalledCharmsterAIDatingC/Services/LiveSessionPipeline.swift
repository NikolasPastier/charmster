import Foundation
import AVFoundation
@preconcurrency import AVFoundation
import Observation
import UIKit

/// Captures mic audio + samples camera frames during a live session and exposes
/// derived signals for SessionScorer. When the camera/mic are unavailable, the
/// pipeline degrades to voice-only or fully mock (Step 8 fallback).
///
/// Real face/body/synchrony analysis happens server-side via a Supabase edge
/// function (mirrors CoachService). This client owns capture + sample upload.
@Observable
final class LiveSessionPipeline: NSObject {

    enum Status { case idle, requestingPermission, running, voiceOnly, mockFallback, failed(String) }

    var status: Status = .idle
    var cameraAvailable: Bool = false
    var micAvailable: Bool = false
    var liveFeel: Double = 0.55         // 0..1, smoothed live "feel" meter
    var partnerSpeaking: Bool = false
    var captionsBuffer: String = ""

    /// Accumulated signals — read at session end to feed the scorer.
    private(set) var signals = SessionSignals()

    private let captureQueue = DispatchQueue(label: "charmster.capture")

    // MARK: - Start / stop (mocked capture for MVP)

    func start(prefersCamera: Bool) async {
        status = .requestingPermission
        let mic = await requestMic()
        let cam = prefersCamera ? await requestCamera() : false
        micAvailable = mic
        cameraAvailable = cam

        if !mic {
            status = .mockFallback
            signals.cameraAvailable = false
            return
        }
        signals.cameraAvailable = cam
        status = cam ? .running : .voiceOnly
        // Real implementation: spin up AVCaptureSession + AVAudioEngine, sample
        // frames at 1fps, stream audio chunks + sampled frames to the analysis
        // edge function, and feed responses back into `signals`.
    }

    func stop() {
        status = .idle
    }

    /// Mock signal walker used by the live UI to animate the feel meter and
    /// produce plausible captions when no real backend is wired.
    func tickMockSignals() {
        liveFeel = max(0.2, min(0.95, liveFeel + Double.random(in: -0.06...0.08)))
        if Bool.random() { partnerSpeaking.toggle() }
        signals.meanVoiceEnergy   = liveFeel
        signals.voiceVariation    = 0.5 + Double.random(in: -0.2...0.2)
        signals.faceEngagement    = cameraAvailable ? liveFeel : nil
        signals.bodyOpenness      = cameraAvailable ? max(0.4, liveFeel - 0.05) : nil
        signals.synchrony         = 0.55 + Double.random(in: -0.15...0.15)
        signals.responseLatencyMean = 1.0 + Double.random(in: -0.3...0.6)
        signals.partnerWarmth     = liveFeel
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
}
