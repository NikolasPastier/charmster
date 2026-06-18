## Charmster — App Plan

Audio-first dating-skills coaching app. Lectures are delivered as a swipeable, audio-first 5-beat story player (Hook, Core Insight, Good vs Bad, Recall Check, Takeaway/Handoff) in the selected coach's voice, followed by live practice. Visual language is the dark "Aura" system (Theme tokens, love-spectrum gradients, feathered coach clips).

### Lecture Story Player (current)
- One beat per card; narration is AUDIO only, on-screen shows a single short signal phrase (signaling principle, never full script).
- FX9.6 / UX4: signal phrase now renders via `KeyPointPopView` — a Duolingo-style pop + settle with an Aura highlight sweep and a light landing haptic, animating once per beat (keyed on beat id), with a Reduce Motion fade fallback.
- Optional `CoachPopInOverlay` adds a sparing coach PiP "pop-in" with 1-line flavor micro-text on the Hook and Takeaway beats only; Reduce Motion downgrades the slide to a fade. No new narration is introduced.
- Reuses existing `LectureBeat` model, `LectureStoryBuilder`, and `AuraCoachStage`.

### Architecture / decisions
- Design tokens centralized in `Theme.swift`; dark-only resolution.
- Beat model: `Models/LectureBeat.swift` (`signalPhrase` is the single on-screen key text).
- Haptics via `UIImpactFeedbackGenerator`, gated by Reduce Motion.