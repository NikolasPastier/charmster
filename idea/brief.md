## Charmster — App Plan

### Concept
Charmster is a private, judgment-free dating-confidence coach. Users learn through short audio-first lectures delivered by a chosen human-named coach character, then practice real conversations with an AI partner (live video+voice) and get scored feedback. Dark, cinematic "noir-tech" base lit by a warm love-spectrum Aura gradient.

### Target audience
People who want to build real-world conversational/dating confidence in a safe, repeatable, gamified way.

### Core loop
Pick coach + partner + setting → watch a 5-beat Aura lecture → live practice session → scored results + journal → repeat along a science-based path, gated by a daily practice cap and a Superwall paywall.

### Key features (current state)
- 13-step conversion onboarding (goal → coach style → attachment/flirting → daily goal + reminder → name + avatar → privacy primer → account + 17+ gate → personalized plan → free taster session → paywall handoff).
- 5 coach characters (Theo, Dr. Ray, Cole, Noah, Leo) mapped onto 5 tone engines; human name shown in-game, role/desc on selection surfaces.
- Photoreal coach visuals via Supabase Storage: stills across all surfaces; coach VIDEO clips (idle + 2 talking takes) wired into the lecture player, cached, force-muted.
- Audio-first 5-beat lecture story player with per-beat coach-voice narration (TTS; pre-gen MP3 wireable later).
- Aura lecture screen matching approved mockups: deep #0B0910 base, pink→gold radial glow halo, edge vignette, segmented progress bar with X exit + beat timer, coach clip feathered full-bleed.
- Friction-aware lecture setup: a lecture's FIRST play (not yet completed) skips the configurator and auto-resolves the session config from the onboarding profile via SessionConfig.recommended, with a brief "Playing with your profile settings" micro-label (profile read-only). REPLAY of a completed lecture opens a lightweight LectureReplaySetupView sheet (coach + difficulty, pre-filled), session-only unless "Save as my default" is on. PracticeConfiguratorView retained for the sandbox flow.
- CATEGORY-PARALLEL unlock model: the first lecture of every track is unlocked from day one and users can progress multiple tracks simultaneously. Within a track, completing lecture N (one full play → LectureProgress.practiced) unlocks N+1; a track's capstone unlocks once all its regular lectures are completed. There are NO global linear locks across categories. Completed lectures are always replayable. Tapping a locked lecture surfaces a soft, encouraging hint ("Finish X to unlock this") rather than a hard error.
- Live AI practice pipeline (AVCapture + OpenAI Realtime WebSocket + sampled-frame vision review), SessionScorer on real signals.
- Aura economy / streaks, journal, results, roadmap/path, profile + settings.

### Theming (single source of truth)
- `Theme.swift` is the single source of truth for semantic tokens plus scheme-independent brand accents and gradients (pink #FF4D94 → gold #FFC23D, plum-violet). Adaptive Light/Dark base; DARK is the fresh-install default. One root `.preferredColorScheme` re-skins the whole app live.

### Architecture / single sources of truth
- `CoachClipCatalog`, `CoachAvatarView`, `AuraCoachStage` / `AuraGlowLayer`, `LectureBeatNarrator`.
- `SessionConfig.recommended(from:lecture:)` — single derivation of a session config from the onboarding profile; reused by first-play auto-config and replay overrides.
- `AppState.isUnlocked(_:)` — THE single source of truth for unlock eligibility (category-parallel, within-category sequential). `AppState.unlockPrerequisite(for:)` drives the soft locked hint. `state(of:)` delegates to `isUnlocked`; never duplicated across views.
- `Curriculum` — curriculum shape (tracks/lectures/capstones), categories via `lectures(in:)`.
- `Theme`, Supabase (auth + DB + Storage, configured).

### Audio rule (hard constraint)
Coach video clips are ALWAYS silent (force-muted). The per-beat lecture narration is the only audio.

### v1 status
Local-first/mock-safe where assets are missing. Superwall paywall handoff present. Pre-generated lecture MP3 narration remains a future upgrade (currently TTS). A per-lecture tone/style axis beyond coach persona, and explicit cross-category prerequisite data, are future TODOs.