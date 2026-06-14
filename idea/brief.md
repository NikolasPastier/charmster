## Charmster — App Plan

### Concept
Charmster is a dark, content-forward iOS coaching app for practicing real conversations and confidence. Users join a named coach character, run live video+voice practice sessions, get scored on an "Aura" system, and follow a daily path of lectures + practice with weekly content drops.

### Target Audience
People who want low-pressure, judgment-free reps at conversation/social confidence, with a personalized coach and measurable growth.

### Core Loop
1. Onboarding personalization quiz → join a coach.
2. Today hero prescribes the next step on the path.
3. Lecture/teaching beat → live practice session (video+voice) → scored debrief.
4. Journal tracks Aura trends, personal bests, and the coach's memory line.
5. Weekly drops + Superwall paywall for the full pack.

### Coaches (characters over 5 tone engines)
Theo (Big Brother), Dr. Ray (Scientist), Cole (Alpha Mentor), Noah (Therapist), Leo (Wingman). `CoachPersona` is the single source of truth; in-game UI shows the human name only.

### Coach Visuals (current state)
- All coach avatar surfaces route through one path: `CoachAvatarView` → `CoachClipCatalog`.
- Uploaded Supabase stills (`Avatars/Coaches/{id}/stills/{id} neutral cutout.png`) now resolve as each coach's photo everywhere (gallery, detail/join, Profile/Settings chips, Today hero, Journal, Results byline). `dr_ray` maps to storage folder `ray`.
- Video clips are not uploaded yet; every state resolves to the still. Dropping in clip URLs later (`objectPath`) is a data-only change — the player crossfades over the still automatically.

### Architecture / Data
- SwiftUI (iOS 26), `@Observable` `AppState`, services for clips/avatars/scoring/curriculum.
- Supabase: public `Avatars` bucket for coach/partner stills + clips; edge functions `realtime_session` + `vision_review` for the live pipeline.
- Superwall for the paywall (post-onboarding handoff).
- Offline SplitMix64 mock is fallback-only.

### v1 Scope Status
Onboarding (13-step), coach gallery/join, live review pipeline, photoreal avatars, daily path, journal, and Superwall handoff are in place. Coach still images are now wired to real Supabase assets.