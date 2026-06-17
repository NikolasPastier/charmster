## Charmster — App Plan

### Concept
Charmster is a dark, cinematic iOS coaching app that teaches dating/social charisma through an audio-first, swipeable lecture "story" experience with photoreal AI coaches, a Duolingo-style learning path, live practice sessions, and an Aura/streak progression economy.

### Design Direction
- Dark "noir-tech" base (#0B0910) lit by a plum→pink→gold Aura gradient.
- App is now DARK-ONLY. No light theme, no Appearance setting. All `Theme` tokens resolve to dark values regardless of device appearance or legacy profile preference.

### Core Surfaces
- Path/Roadmap (home): Today hero, weekly drop shelf, category-parallel lecture path. Header shows edge-pinned Streak (left) and Aura (right) pills, no center logo.
- Lecture Story Player: audio-first 5-beat narration with coach video clips + Aura stage.
- Live Practice: AVCapture + OpenAI Realtime review pipeline with scoring.
- Onboarding: 13-step conversion flow ending in free taster + Superwall paywall.
- Settings/Profile: personalization, learning goals/reminders, membership, support. All rows single-line.

### Architecture / Data
- `AppState` holds profile + progression; `Theme` is the single design-token source (dark-only).
- Supabase backend for coach stills/clips, lecture audio, avatars. Superwall for monetization.
- `themePreference` field retained (default "dark") for storage compatibility but no longer read for theming.

### V1 Status
Shipped and dark-locked. Mock/offline fallbacks remain for AV and audio paths.