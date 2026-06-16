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
- Photoreal coach visuals via Supabase Storage: stills wired across all surfaces; **coach VIDEO clips (idle + 2 talking takes) now wired into the lecture player**, cached on device, force-muted.
- Audio-first 5-beat lecture story player (hook / core insight / good-vs-bad / recall / takeaway) with per-beat coach-voice narration (TTS; pre-gen MP3 wireable later).
- **Aura lecture screen** matching approved mockups: deep #0B0910 base, soft pink→gold radial glow halo behind the coach, edge vignette, slim segmented progress bar with X exit + beat timer, and the coach clip feathered full-bleed (alpha mask + vignette) into the scene — never a hard video edge.
- Live AI practice pipeline (AVCapture + OpenAI Realtime WebSocket + sampled-frame vision review), SessionScorer on real signals.
- Aura economy / streaks, journal, results, roadmap/path, profile + settings.

### Architecture / single sources of truth
- `CoachClipCatalog` — coach clip/still URL resolution + on-disk cache; one `coachClipURL(id:state:index:)` helper owns path + percent-encoding.
- `CoachAvatarView` — coach clip player with crossfade, looping, still fallback, and force-mute (isMuted + volume 0 + AVMutableAudioMix zeroing every audio track).
- `AuraCoachStage` — reuses CoachAvatarView and adds the glow halo + feathered alpha mask + vignette.
- `LectureBeatNarrator` — the ONLY audio source in the lecture (coach TTS, .playback/.spokenAudio session); clip players never contribute audio.
- `LectureStoryBuilder` / `LectureContentStore` — lecture copy/quiz + derived beats.
- `Theme` — design tokens (Aura gradient, palette, radii).
- Supabase — auth + DB + Storage (Avatars/Coaches/<id>/clips + stills, user-avatars, app logo). Configured.

### Audio rule (hard constraint)
Coach video clips are ALWAYS silent (force-muted, audio tracks zeroed). The pre-generated per-beat lecture narration is the only audio.

### v1 status
Local-first/mock-safe where assets are missing (offline → coach still, never black). Superwall paywall handoff present. Pre-generated lecture MP3 narration remains a future upgrade (currently TTS).