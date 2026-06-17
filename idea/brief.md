## Charmster — App Plan

### Concept
Charmster is a dark, cinematic iOS coaching app that teaches dating/social charisma through an audio-first, swipeable lecture "story" experience with photoreal AI coaches, a Duolingo-style learning path, live practice sessions, and an Aura/streak progression economy.

### Design Direction
- Dark "noir-tech" base (#0B0910) lit by a plum→pink→gold Aura gradient.
- App is DARK-ONLY. No light theme, no Appearance setting. All `Theme` tokens resolve to dark values.

### Core Surfaces
- Path/Roadmap (home): Today hero, weekly drop shelf, category-parallel lecture path. Edge-pinned Streak (left) and Aura (right) pills, no center logo.
- Lecture Story Player: audio-first 5-beat narration. Beats now match the approved sketch — every beat inherits the shared `AuraBackground` glow; one title per beat; per-beat coach treatment (full framed coach ONLY on Hook + Takeaway; Core Insight shows a cached teaching visual full-card with at most a tiny circular coach PiP; Good vs Bad and Recall show no coach). Good vs Bad is two side-by-side WORKS/AVOID cards.
- Live Practice: AVCapture + OpenAI Realtime review pipeline with scoring.
- Onboarding: 13-step conversion flow ending in free taster + Superwall paywall.
- Settings/Profile: personalization, learning goals/reminders, membership, support. Single-line rows.

### Architecture / Data
- `AppState` holds profile + progression; `Theme` is the single design-token source (dark-only).
- `LectureStoryBuilder` derives the 5-beat story; `LectureBeat.visual` drives per-beat rendering in `LectureStoryPlayerView`.
- Teaching visuals: `InsightVisualURL` maps each lecture (via its existing `skill` dimension, no data migration) to a cached `lecture-visuals/{key}.jpg` in Supabase storage (`firstImpressions`, `presence`, `conversationFlow`) with a neutral Aura fallback. Same ~$0-runtime caching pattern as coach clips/audio.
- Supabase backend for coach stills/clips, lecture audio, teaching visuals, avatars. Superwall for monetization.

### V1 Status
Shipped and dark-locked. Lecture UI v2 matches the sketch. Mock/offline fallbacks remain for AV and audio paths. Teaching-visual images for the three keys still need to be uploaded to the `lecture-visuals` bucket; until then Core Insight uses the neutral Aura fallback.