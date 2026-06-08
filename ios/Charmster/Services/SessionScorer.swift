import Foundation

/// Deterministic mock RNG for offline scoring.
private struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func nextDouble() -> Double {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z =  z ^ (z >> 31)
        return Double(z >> 11) / Double(UInt64(1) << 53)
    }
}

/// Raw signals captured during a session. Real implementations populate these
/// from mic prosody, the live transcript, and sampled vision frames.
/// When `nil`, SessionScorer falls back to the deterministic mock.
struct SessionSignals {
    var transcript: String?
    var meanVoiceEnergy: Double?     // 0..1
    var voiceVariation: Double?      // 0..1
    var faceEngagement: Double?      // 0..1 (smile + eye contact composite)
    var bodyOpenness: Double?        // 0..1
    var synchrony: Double?           // 0..1 (turn-taking + mirroring)
    var responseLatencyMean: Double? // seconds
    var partnerWarmth: Double?       // 0..1 — from analysis backend
    var cameraAvailable: Bool = true
}

enum SessionScorer {

    /// Score the session. If `signals` carries real measurements, use them; otherwise
    /// fall back to a deterministic mock (so previews & offline still work).
    /// Step 8: safety gate — if comfort < 50, sessionScore is capped at 65.
    static func score(
        lecture: Lecture?,
        durationSeconds: Int,
        tier: DifficultyTier,
        coach: CoachStyle,
        signals: SessionSignals,
        isSandbox: Bool,
        sandboxScored: Bool
    ) -> SessionResult {

        let seed = UInt64(durationSeconds &+ 17) &* 0xA5A5_A5A5
        var rng = SplitMix64(seed: seed)

        func mockOr(_ real: Double?) -> Double {
            real ?? (0.55 + rng.nextDouble() * 0.35)
        }

        let voiceD       = mockOr(signals.meanVoiceEnergy)
        let voiceVarD    = mockOr(signals.voiceVariation)
        let faceD        = signals.cameraAvailable ? mockOr(signals.faceEngagement) : 0.5
        let bodyD        = signals.cameraAvailable ? mockOr(signals.bodyOpenness)   : 0.5
        let synchronyD   = mockOr(signals.synchrony)
        let respLatency  = signals.responseLatencyMean ?? (0.8 + rng.nextDouble() * 1.2)
        let warmthD      = mockOr(signals.partnerWarmth)

        // 0..100
        let voice          = clamp(Int((voiceD * 0.6 + voiceVarD * 0.4) * 100))
        let face           = clamp(Int(faceD * 100))
        let body           = clamp(Int(bodyD * 100))
        let synchrony      = clamp(Int(synchronyD * 100))
        let responsiveness = clamp(Int((1.0 - min(respLatency / 4.0, 1.0)) * 100))
        let calibration    = clamp(Int(((warmthD + synchronyD) / 2.0) * 100))
        let comfort        = clamp(Int(((1.0 - abs(0.5 - voiceVarD)) * 0.5 + warmthD * 0.5) * 100))

        var session = (voice + face + body + synchrony + responsiveness + calibration) / 6
        var safetyCap = false
        if comfort < 50 && session > 65 {
            session = 65
            safetyCap = true
        }

        // Aura is the sole progression metric.
        let auraBase: Int
        if let lec = lecture {
            auraBase = lec.isCapstone ? 120 : 50
        } else {
            auraBase = 35
        }
        var aura = Int(Double(auraBase) * tier.xpMultiplier * Double(session) / 80.0)
        if isSandbox && sandboxScored { aura = Int(Double(aura) * 0.5) }
        if isSandbox && !sandboxScored { aura = 0 }

        let coins = 10 // disabled in UI but kept for data integrity

        return SessionResult(
            id: UUID(),
            lectureId: lecture?.id,
            isCapstone: lecture?.isCapstone ?? false,
            isSandbox: isSandbox,
            responsiveness: responsiveness,
            voice: voice,
            face: face,
            body: body,
            synchrony: synchrony,
            calibration: calibration,
            comfort: comfort,
            sessionScore: session,
            auraEarned: aura,
            streakKept: session >= 60,
            coinsEarned: coins,
            durationSeconds: durationSeconds,
            safetyCapApplied: safetyCap,
            createdAt: .now
        )
    }

    private static func clamp(_ v: Int, lo: Int = 0, hi: Int = 100) -> Int {
        max(lo, min(hi, v))
    }
}
