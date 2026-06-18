## Charmster — App Plan

Audio-first dating-skills coaching app. Lectures are delivered as a swipeable, audio-first story player (silent Card 0 "What you'll learn" → 5-beat structure → live practice). Live practice is a real-time voice/video rehearsal with an AI practice partner, scored at session end. Visual language is the dark "Aura" system (Theme tokens, love-spectrum gradients, feathered coach clips).

### Live Practice (current)
- Real-time partner via `LiveSessionPipeline` → `RealtimeLiveSession` (OpenAI Realtime). Mic+camera capture, per-turn mood tags, atmosphere meter, end-of-session scoring via `SessionScorer`.
- UX4 — **Coach Nudges**: after each completed user turn, the selected coach gives ONE brief cue at the bottom of the screen (praise / improvement / calibration), in the coach persona's voice, driven by the latest utterance + avatar feeling (`lastMoodTag`) + atmosphere intensity. On-device deterministic generation (no new network call), fail-silent. Bar sits above the controls, never blocks typing/scroll; "Try this" reveals a rewrite, "Why" reveals rationale; swipe-down/X dismiss; praise auto-hides ~5s, critical ~8s. Reduced-motion = fade only.

### Architecture / decisions
- Nudge model `Models/Nudge.swift`; engine + rate-limiting coordinator `Services/CoachNudgeEngine.swift`; UI `Components/CoachNudgeBar.swift`.
- Anti-spam (required): max 1 nudge per N user turns (Minimal 3 / Coaching 2), never two improvements back-to-back, confidence floor per level, Minimal = praise-only, Off = disabled.
- Turn trigger: `RealtimeLiveSession.userTurnCount` increments on transcription-completed, mirrored onto the pipeline; view observes it.
- Setting: `PersonalizationProfile.nudgeLevel` (Off/Minimal/Coaching, default Coaching, Codable-safe) + Settings → Coaching & difficulty picker.
- Design tokens centralized in `Theme.swift`; haptics gated by Sound & Haptics + Reduce Motion.

### Lecture Story Player
- Card 0 "What you'll learn" objectives prelude + 5 audio beats (Hook, Core Insight, Good vs Bad, Recall Check, Takeaway). Duolingo-style key-point pops, optional coach pop-in. `LectureStoryBuilder` derives objectives from existing content (no curriculum rewrite).