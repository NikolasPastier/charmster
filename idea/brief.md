## Charmster — App Plan

### Concept
Charmster is a dark, cinematic iOS coaching app that teaches dating/social charisma through an audio-first, swipeable lecture "story" experience with photoreal AI coaches, a Duolingo-style learning path, live practice sessions, and an Aura/streak progression economy.

### Design Direction
- Dark "noir-tech" base (#0B0910) lit by a plum→pink→gold Aura gradient.
- App is DARK-ONLY. No light theme, no Appearance setting. All `Theme` tokens resolve to dark values.

### Core Surfaces
- Path/Roadmap (home): Today hero, weekly drop shelf, category-parallel lecture path. Edge-pinned Streak (left) and Aura (right) pills, no center logo.
- Lecture Story Player: audio-first 5-beat narration. Every beat inherits the shared `AuraBackground` glow; one title per beat; per-beat coach treatment (full framed coach ONLY on Hook + Takeaway; Core Insight shows a cached teaching visual full-card with at most a tiny circular coach PiP; Good vs Bad and Recall show no coach). Good vs Bad is two side-by-side WORKS/AVOID cards. The coach now VISIBLY loops (idle↔talking in sync with each beat's MP3) instead of showing a frozen still.
- Live Practice: AVCapture + OpenAI Realtime review pipeline with scoring.
- Onboarding: 13-step conversion flow ending in free taster + Superwall paywall.
- Settings/Profile: personalization, learning goals/reminders, membership, support. Single-line rows.

### Architecture / Data
- `AppState` holds profile + progression; `Theme` is the single design-token source (dark-only).
- `LectureStoryBuilder` derives the 5-beat story; `LectureBeat.visual` drives per-beat rendering in `LectureStoryPlayerView`.
- Video playback: ONE shared `LoopingVideoPlayer(url:muted:clipID:)` (retained AVPlayer + seek-to-zero loop + sized AVPlayerLayer, the proven female-avatar pattern). Both the female practice avatar (`AvatarView` base loop) and the coach lecture avatar (`CoachAvatarView` via `AuraCoachStage`) render through it. Muting is `player.isMuted` only — the old synchronous `asset.tracks` audio-mix (which stalled coach item readiness and left a frozen still) is removed. The fallback still sits behind the video and crossfades off on first `.readyToPlay` frame.
- Coach clips/audio/teaching-visuals: cached public Supabase Storage assets (~$0 runtime), resolved via `CoachClipCatalog`, `LectureAudioURL`, `InsightVisualURL`.
- Supabase backend for coach stills/clips, lecture audio, teaching visuals, avatars. Superwall for monetization.

### V1 Status
Shipped and dark-locked. Lecture UI v2 matches the sketch. Coach lecture clips now play (single shared playback stack). Mock/offline fallbacks remain for AV and audio paths. Teaching-visual images for the three keys still need to be uploaded to the `lecture-visuals` bucket; until then Core Insight uses the neutral Aura fallback.