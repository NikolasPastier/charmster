## Charmster — App Plan

### Concept
Charmster is a dark, content-forward iOS coaching app for practicing real conversations and confidence. Users join a named coach character, run live video+voice practice sessions, get scored on an "Aura" system, and follow a daily path of lectures + practice with weekly content drops.

### Target Audience
People who want low-pressure, judgment-free reps at conversation/social confidence, with a personalized coach and measurable growth.

### Core Loop
1. Onboarding personalization quiz → pick a practice partner → join a coach.
2. Today hero prescribes the next step on the path.
3. Lecture/teaching beat → live practice session (video+voice) → scored debrief.
4. Journal tracks Aura trends, personal bests, and the coach's memory line.
5. Weekly drops + Superwall paywall for the full pack.

### Coaches (characters over 5 tone engines)
Theo (Big Brother), Dr. Ray (Scientist), Cole (Alpha Mentor), Noah (Therapist), Leo (Wingman). `CoachPersona` is the single source of truth; in-game UI shows the human name only.

### Practice Partners (avatars)
Two parallel partner models exist:
- `AvatarPersona` (ids `mia`, `mateo`) — the ONBOARDING partner picker + plan-ready hero. Display names: Mia, **Matteo** (two t's, matching storage folder `Matteo photoreal`).
- `PartnerPersona` (CoreTypes: mia/matteo/zoe) — the LIVE practice session model.

### Coach Visuals
- All coach avatar surfaces route through `CoachAvatarView` → `CoachClipCatalog`. Supabase stills resolve as each coach's photo everywhere; `dr_ray` maps to folder `ray`. Clips not uploaded yet → still fallback.

### Partner Visuals (current state)
- Onboarding partner cards + plan-ready hero now show REAL Supabase stills via `PartnerStillImageURL` + `PartnerStillImage` view.
- Scheme: `{DisplayName} photoreal/stills/{DisplayName} neutral {cutout|scene}.jpeg` (percent-encoded). Cards use `cutout`; hero uses `scene`. Adding a partner is data-only.
- On load failure → SF Symbol placeholder (never a black frame).
- Matteo motion CLIPS not uploaded yet; live-practice avatar still falls back to Aura layer for Matteo.

### Name Source of Truth (resolved)
- USER name = `profile.name`, set authoritatively from the account-screen Username. Drives greeting, Profile, and Settings.
- PARTNER name = `profile.avatarName`, set only on the partner screen ("Their name"). Drives "Practicing with …".
- The partner screen's old "Your name (optional)" input (which wrote `profile.name`) was REMOVED to eliminate the path where the partner screen overwrote the user's name.

### Architecture / Data
- SwiftUI (iOS 26), `@Observable` `AppState`, services for clips/avatars/scoring/curriculum.
- Supabase: public `Avatars` bucket for coach/partner stills + clips; edge functions `realtime_session` + `vision_review` for the live pipeline.
- Superwall for the paywall (post-onboarding handoff).
- Offline SplitMix64 mock is fallback-only.

### v1 Scope Status
Onboarding (13-step), coach gallery/join, live review pipeline, photoreal avatars, daily path, journal, and Superwall handoff are in place. Coach AND onboarding-partner still images are now wired to real Supabase assets, and the user-name handling is fixed end to end.