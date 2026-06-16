## Charmster — App Plan

### Concept
Charmster is a private, judgment-free dating-confidence coach. Users learn a science-based curriculum through short lectures, then practice with a realistic AI partner in live video/voice sessions and get real-time, dimension-scored feedback. Progress is a single 0–100 Aura metric reinforced by mastery + spaced repetition.

### Target audience
People who want to build real-world conversational/dating confidence in a low-stakes, coached environment.

### Core loop
Lecture (teach the skill) → Live practice with AI partner → Scored results + debrief → Mastery/SRS resurfaces weak skills over time.

### Key systems (single sources of truth)
- **Curriculum**: `Resources/curriculum.json` → `Curriculum`/`Lecture`; teaching copy + quizzes in `LectureContentStore` (coach-styled variants).
- **Coaches**: `CoachPersona` named characters over the 5 `CoachStyle` tone engines; per-coach voice (preview MP3s; offline AVSpeech fallback).
- **Avatars**: photoreal clip system (`AvatarView`/`CoachAvatarView` + clip catalogs) with clip-optional still fallback, hot-swappable via manifest.
- **Economy**: `AppState.aura` (0–100 EMA), mastery tiers, SM-2 spaced repetition (`dueReviews`/`ReviewHubView`).
- **Live practice**: AVCapture + OpenAI Realtime + vision review pipeline; `SessionScorer`.
- **Onboarding**: 13-step conversion flow → free taster → Superwall paywall handoff.

### Pre-practice lecture experience (current delivery)
The lecture is an **audio-first, swipeable 5-beat story-card player** (replacing the old stacked text-block popup), non-destructively reusing lecture content, coach voice/persona, the avatar clip system, and the Aura economy:
- 5 ordered beats: hook, coreInsight, goodVsBad, recallCheck, takeawayHandoff (`LectureBeat`/`LectureStory`, derived by `LectureStoryBuilder`).
- Each lecture carries `conversationMode` (inPerson default; texting only when explicitly about messaging). GoodVsBad renders **spoken-line cards** (in-person) or **chat-bubble mockups** (texting) via shared `TeachingVisuals`.
- Audio-first narration per beat (`LectureBeatNarrator`) with auto-advance; minimal on-screen text (signal phrase only); captions OFF by default + toggle; skip-to-practice.
- Avatar talking-loop under audio on hook/takeaway; PiP avatar voiceover on insight/goodVsBad; reduced-motion + clip-missing both fall back to coach stills.
- One active-recall tap with instant feedback + one-line why + Aura ping (`awardRecallPing`).
- Energizing handoff card (`LectureHandoffView`) → existing configurator → live practice. Re-watchable via Library/SRS surfaces.

### Integrations
Supabase (auth + DB + Storage, configured), OpenAI (backend, live realtime/vision), Superwall (paywall handoff).

### Notes / TODOs
- Lecture narration uses tuned offline AVSpeech today; pre-generated per-(lecture,coach,beat) MP3s can be wired into `LectureBeatNarrator` later (interface ready).
- `Services/TeachingNarrator.swift` now unused (left in place; safe to remove later).