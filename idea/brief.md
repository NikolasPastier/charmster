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
- Friction-aware lecture setup: a lecture's FIRST play (LectureProgress.practiced == false) skips the configurator entirely and auto-resolves the session config from the onboarding profile via SessionConfig.recommended, with a brief "Playing with your profile settings" micro-label (profile is read-only here). REPLAY of a completed lecture opens a lightweight LectureReplaySetupView sheet (coach avatars + difficulty, pre-filled) whose choices apply to that session only unless "Save as my default" is on. Results card and mastered path nodes surface a replay affordance. PracticeConfiguratorView is retained for the sandbox flow.
- Live AI practice pipeline (AVCapture + OpenAI Realtime WebSocket + sampled-frame vision review), SessionScorer on real signals.
- Aura economy / streaks, journal, results, roadmap/path, profile + settings.

### Theming (single source of truth)
- `Theme.swift` is the single source of truth for semantic tokens (bg, surface, surfaceRaised, border, text/textMuted/textFaint) plus scheme-independent brand accents and gradients (pink #FF4D94 → gold #FFC23D, plum-violet).
- Base tokens use adaptive `Color(lightHex:darkHex:)`; one root `.preferredColorScheme` in `App.swift` re-skins the whole app live. Only bg/surface/text differ between Light and Dark — brand accents/gradients/Aura glow are preserved in both.
- DARK is the default Charmster look on a fresh install (`PersonalizationProfile.themePreference` defaults to "dark"); persisted Light/System choices still decode and apply unchanged. Dark / Light / System toggle lives in Settings; the Aura background (`AuraGlowLayer` / `AuraCoachStage` / `Theme.bg`) is the standard app surface app-wide.

### Architecture / single sources of truth
- `CoachClipCatalog` — coach clip/still URL resolution + on-disk cache.
- `CoachAvatarView` — coach clip player with crossfade, looping, still fallback, force-mute.
- `AuraCoachStage` / `AuraGlowLayer` — glow halo + feathered mask + vignette over `Theme.bg`.
- `LectureBeatNarrator` — the ONLY audio source in the lecture (coach TTS).
- `SessionConfig.recommended(from:lecture:)` — single derivation of a session config from the onboarding profile; reused by both first-play auto-config and replay overrides.
- `Theme` — design tokens (Aura gradient, palette, radii, adaptive Light/Dark base).
- Supabase — auth + DB + Storage. Configured.

### Audio rule (hard constraint)
Coach video clips are ALWAYS silent (force-muted, audio tracks zeroed). The pre-generated per-beat lecture narration is the only audio.

### v1 status
Local-first/mock-safe where assets are missing (offline → coach still, never black). Superwall paywall handoff present. Pre-generated lecture MP3 narration remains a future upgrade (currently TTS). A per-lecture tone/style axis beyond coach persona is a future TODO.