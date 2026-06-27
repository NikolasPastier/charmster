import Foundation

/// Deterministic mock RNG for offline / preview scoring.
private struct SplitMix64 {
  private var state: UInt64
  init(seed: UInt64) { self.state = seed &+ 0x9E37_79B9_7F4A_7C15 }
  mutating func nextDouble() -> Double {
    state = state &+ 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    z = z ^ (z >> 31)
    return Double(z >> 11) / Double(UInt64(1) << 53)
  }
}

// MARK: - Session signals

/// Raw signals captured during a session.
/// Real values come from mic prosody, vision frames, and the transcript judge.
/// nil → SessionScorer falls back to the deterministic mock for that slot.
struct SessionSignals {
  var transcript: String?
  var meanVoiceEnergy: Double?  // 0..1
  var voiceVariation: Double?   // 0..1
  var faceEngagement: Double?   // 0..1 (smile + eye contact)
  var bodyOpenness: Double?     // 0..1 (posture + framing)
  var synchrony: Double?        // 0..1 (turn-taking + mirroring)
  var responseLatencyMean: Double?  // seconds
  var partnerWarmth: Double?    // 0..1 — mood-tag proxy
  var cameraAvailable: Bool = true
  var practiceMode: PracticeMode = .videoVoice

  // Filled by SessionScoreService at session end.
  var judgedResponsiveness: Int?
  var judgedCalibration: Int?
  var judgedComfort: Int?
  var judgedInterest: Int?
  var judgedSpark: Int?
  var judgedRespect: Int?
  var reactionLine: String?
  var strengths: [String]?
  var fixes: [String]?
}

// MARK: - Scorer

enum SessionScorer {

  /// Score the session.
  ///
  /// Algorithm:
  ///  1. Channel dropping — zero out dims unavailable in this mode, renormalise weights.
  ///  2. On-device dims: voice, face, body, synchrony (mock fallback when nil).
  ///  3. Judged dims: responsiveness + calibration from transcript judge (proxy fallback).
  ///  4. rawScore  = weightedAverage(active dims, scoringProfile)
  ///  5. feelScore = 0.30·comfort + 0.25·interest + 0.30·spark + 0.15·respect  (judge)
  ///  6. session   = round(0.5·rawScore + 0.5·feelScore)
  ///  7. Safety gate: comfort < 50 → cap session at 65.
  ///  8. Aura EMA (unchanged): tier-weighted blend of oldAura toward session.
  static func score(
    lecture: Lecture?,
    durationSeconds: Int,
    tier: DifficultyTier,
    coach: CoachStyle,
    signals: SessionSignals,
    isSandbox: Bool,
    sandboxScored: Bool,
    currentAura: Int
  ) -> SessionResult {

    let seed = UInt64(durationSeconds &+ 17) &* 0xA5A5_A5A5
    var rng = SplitMix64(seed: seed)
    func mockOr(_ real: Double?) -> Double {
      real ?? (0.55 + rng.nextDouble() * 0.35)
    }

    // ── 1. Channel availability ───────────────────────────────────────────────
    let textOnly  = signals.practiceMode == .text
    let noCamera  = !signals.cameraAvailable || textOnly
    let noVoice   = textOnly

    // ── 2. On-device dimensions ───────────────────────────────────────────────
    let voiceDim: Int? = noVoice ? nil : {
      let e = mockOr(signals.meanVoiceEnergy)
      let v = mockOr(signals.voiceVariation)
      return clamp(Int((e * 0.6 + v * 0.4) * 100))
    }()

    let faceDim: Int? = noCamera ? nil :
      clamp(Int(mockOr(signals.faceEngagement) * 100))

    let bodyDim: Int? = noCamera ? nil :
      clamp(Int(mockOr(signals.bodyOpenness) * 100))

    let synchronyDim: Int? = noVoice ? nil :
      clamp(Int(mockOr(signals.synchrony) * 100))

    // ── 3. Judged dimensions (transcript) ─────────────────────────────────────
    // Proxy fallback mirrors the old formula so mock/offline sessions still work.
    let responsivenessDim: Int = signals.judgedResponsiveness ?? {
      let lat = signals.responseLatencyMean ?? (0.8 + rng.nextDouble() * 1.2)
      return clamp(Int((1.0 - min(lat / 4.0, 1.0)) * 100))
    }()

    let calibrationDim: Int = signals.judgedCalibration ?? {
      let w = mockOr(signals.partnerWarmth)
      let s = mockOr(signals.synchrony)
      return clamp(Int(((w + s) / 2.0) * 100))
    }()

    // ── 4. Weighted average with channel dropping ─────────────────────────────
    var profile = lecture?.scoringProfile ?? .balanced
    if noVoice  { profile.voice = 0; profile.synchrony = 0 }
    if noCamera { profile.face = 0;  profile.body = 0 }

    typealias DW = (value: Int, weight: Double)
    var dims: [DW] = []
    if let v = voiceDim,    profile.voice         > 0 { dims.append((v, profile.voice)) }
    if let f = faceDim,     profile.face          > 0 { dims.append((f, profile.face)) }
    if let b = bodyDim,     profile.body          > 0 { dims.append((b, profile.body)) }
    if let s = synchronyDim, profile.synchrony    > 0 { dims.append((s, profile.synchrony)) }
    dims.append((responsivenessDim, max(profile.responsiveness, 0.01)))
    dims.append((calibrationDim,    max(profile.calibration,    0.01)))

    let totalWeight = dims.map(\.weight).reduce(0, +)
    let rawScore: Int
    if totalWeight > 0 {
      let weighted = dims.map { Double($0.value) * $0.weight }.reduce(0, +)
      rawScore = clamp(Int((weighted / totalWeight).rounded()))
    } else {
      rawScore = 50
    }

    // ── 5. Feel layer ─────────────────────────────────────────────────────────
    let comfortF  = Double(signals.judgedComfort  ?? 50)
    let interestF = Double(signals.judgedInterest ?? 50)
    let sparkF    = Double(signals.judgedSpark    ?? 50)
    let respectF  = Double(signals.judgedRespect  ?? 50)
    let feelScore = clamp(
      Int((0.30 * comfortF + 0.25 * interestF + 0.30 * sparkF + 0.15 * respectF).rounded()))

    // ── 6 + 7. Blend + safety gate ────────────────────────────────────────────
    var session = clamp(Int((0.5 * Double(rawScore) + 0.5 * Double(feelScore)).rounded()))
    var safetyCap = false
    if comfortF < 50 && session > 65 {
      session = 65
      safetyCap = true
    }

    // ── 8. Aura EMA (tier-weighted, unchanged) ────────────────────────────────
    let baseWeight = 0.20
    var w = baseWeight * tier.tierWeight
    if isSandbox && sandboxScored  { w *= 0.5 }
    if isSandbox && !sandboxScored { w = 0 }
    if w > 0 { w = max(0.05, min(0.40, w)) }

    let oldAura  = max(0, min(100, currentAura))
    let blended  = (1.0 - w) * Double(oldAura) + w * Double(session)
    let newAura  = max(0, min(100, Int(blended.rounded())))
    let auraDelta = newAura - oldAura

    return SessionResult(
      id: UUID(),
      lectureId: lecture?.id,
      isCapstone: lecture?.isCapstone ?? false,
      isSandbox: isSandbox,
      responsiveness: responsivenessDim,
      voice:     voiceDim    ?? 0,
      face:      faceDim     ?? 0,
      body:      bodyDim     ?? 0,
      synchrony: synchronyDim ?? 0,
      calibration: calibrationDim,
      comfort: clamp(Int(comfortF)),
      sessionScore: session,
      auraEarned: auraDelta,
      streakKept: session >= tier.passThreshold,
      coinsEarned: 10,
      durationSeconds: durationSeconds,
      safetyCapApplied: safetyCap,
      createdAt: .now,
      cameraUsed: !noCamera,
      interest: signals.judgedInterest,
      spark:    signals.judgedSpark,
      respect:  signals.judgedRespect,
      reactionLine: signals.reactionLine,
      strengths: signals.strengths,
      fixes:     signals.fixes
    )
  }

  private static func clamp(_ v: Int, lo: Int = 0, hi: Int = 100) -> Int {
    max(lo, min(hi, v))
  }
}
