## Charmster — App Plan

Audio-first dating-skills coaching app. Lectures are delivered as a swipeable, audio-first story player. Each lecture now opens on a silent intro Card 0 ("What you'll learn") and continues into the proven 5-beat structure (Hook, Core Insight, Good vs Bad, Recall Check, Takeaway/Handoff) in the selected coach's voice, followed by live practice. Visual language is the dark "Aura" system (Theme tokens, love-spectrum gradients, feathered coach clips).

### Lecture Story Player (current)
- UX5: every lecture opens on Card 0, a silent "By the end, you'll be able to:" prelude previewing 2–3 outcome lines, then advances into Beat 1 (audio Hook). Card 0 is skippable, has a "Start lecture" CTA, and back from Beat 1 returns to it. Progress bar shows a distinct smaller prelude segment ahead of the 5 beat segments.
- One beat per card; narration is AUDIO only; on-screen shows a single short signal phrase via `KeyPointPopView` (Duolingo-style pop + Aura sweep + light haptic, once per beat, Reduce Motion fade fallback).
- Optional `CoachPopInOverlay` adds a sparing coach PiP pop-in with 1-line flavor on Hook + Takeaway beats only.
- Reuses existing `LectureBeat`/`LectureStory` model, `LectureStoryBuilder`, and `AuraCoachStage`.

### Architecture / decisions
- Design tokens centralized in `Theme.swift`; dark-only resolution.
- Beat model: `Models/LectureBeat.swift`; `LectureStory.learningObjectives` (UX5) is derived by `LectureStoryBuilder` from existing lecture metadata + teaching content — never a curriculum rewrite. Defaulted to `[]` so older decoded stories stay valid (no migration).
- Objective fallback rule: capability line + behavior line + optional "Avoid…" line (only when a bad-example signal already exists).
- Haptics via `UIImpactFeedbackGenerator`, gated by Reduce Motion.