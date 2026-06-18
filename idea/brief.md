## Charmster — App Plan

### Concept
Charmster is a dark, cinematic iOS coaching app that teaches dating/social charisma through an audio-first, swipeable lecture "story" experience with photoreal AI coaches, a Duolingo-style learning path, live practice sessions, and an Aura/streak progression economy.

### Design Direction
- Dark "noir-tech" base (#0B0910) lit by a plum→pink→gold Aura gradient.
- App is DARK-ONLY. No light theme, no Appearance setting. All `Theme` tokens resolve to dark values.

### Core Surfaces
- Path/Roadmap (home): Today hero, weekly drop shelf, category-parallel lecture path. Edge-pinned Streak (left) and Aura (right) pills, no center logo.
- Lecture Story Player: audio-first 5-beat narration. A soft blurred coach STILL (`CoachBackdrop`) glows behind ALL beats — GPU-cheap, static, Aura-tinted (plum→black) — recreating the sketch's "coach behind the content" look without alpha video. Sharp foreground sits on top: full framed coach loop ONLY on Hook + Takeaway; Core Insight shows a cached teaching visual full-card with a tiny circular coach PiP; Good vs Bad is two side-by-side WORKS/AVOID cards; Recall shows the question. The coach VISIBLY loops (idle↔talking in sync with each beat's MP3).
- Live Practice: AVCapture + OpenAI Realtime review pipeline with scoring; overlay controls + atmosphere bar respect safe-area insets.
- Onboarding: 13-step conversion flow ending in free taster + Superwall paywall.
- Settings/Profile: personalization, learning goals/reminders, membership, support. Single-line rows.

### Architecture / Data
- `AppState` holds profile + progression; `Theme` is the single design-token source (dark-only).
- `LectureStoryBuilder` derives the 5-beat story; `LectureBeat.visual` drives per-beat rendering in `LectureStoryPlayerView`.
- Lecture player layering: `AuraBackground` → `CoachBackdrop` (blurred idle still) → sharp beat content.
- Video playback: ONE shared `LoopingVideoPlayer(url:muted:clipID:)` (retained AVPlayer + seek-to-zero loop + sized AVPlayerLayer). Both the female practice avatar (`AvatarView` base loop) and the coach lecture avatar (`CoachAvatarView` via `AuraCoachStage`) render through it. Muting is `player.isMuted` only.
- Coach clips/audio/teaching-visuals: cached public Supabase Storage assets (~$0 runtime), resolved via `CoachClipCatalog`, `LectureAudioURL`, `InsightVisualURL`. `CoachBackdrop` reuses `CoachClipCatalog.idleStill(for:)`.
- Supabase backend for coach stills/clips, lecture audio, teaching visuals, avatars. Superwall for monetization.

### V1 Status
Shipped and dark-locked. Lecture UI v2 matches the sketch with the new blurred coach backdrop behind every beat. Coach lecture clips play (single shared playback stack). Mock/offline fallbacks remain for AV and audio paths. Teaching-visual images for the three keys still need to be uploaded to the `lecture-visuals` bucket; until then Core Insight uses the neutral Aura fallback.