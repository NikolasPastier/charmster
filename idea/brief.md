## Charmster — App Plan

Charmster is a dark, content-forward iOS app for practicing dating/social conversation skills with an AI avatar partner. Onboarding runs a personalization quiz, daily-goal setup, coach selection (join a named coach character), name + avatar selection, privacy primer, and account gate, then reveals a personalized plan and a free taster session before the Superwall paywall handoff.

### Coaches-as-characters + Ladder retention (this prompt owns the foundation)
- `CoachPersona` (Models/CoachPersona.swift) is the SINGLE source of truth for the 5 named coaches (Theo, Dr. Ray, Cole, Noah, Leo). Each persona is a character skin over an existing `CoachStyle` tone engine — `joinCoach` sets `selectedCoachId` AND keeps legacy `coachMode` in sync so the existing system prompt / TTS path is unchanged. In-game UI shows the human name ONLY; roleTag + shortDescription appear only on selection surfaces (gallery / onboarding / Settings).
- `CoachAvatarState` + `CoachClipCatalog` + `CoachAvatarView` are the SINGLE source of truth for coach visuals. Manifest maps `coachId + state -> Avatars/coach-clips/{id}/{state}.mp4`, caches on device, preloads idle+talking, and falls back to an Aura-gradient still when no clip resolves (never a black frame). Swapping real clips in later is a DATA-ONLY change in `objectPath`. The Lecture-Redesign prompt reuses these as-is.
- `DailyRouter` produces ONE prescribed session per day in priority order (path step → decaying spaced-rep drill → unseen weekly drop → Gold stretch), reusing existing engines — no parallel system. Surfaced by the Today hero atop the Path tab.
- `WeeklyDrop` rotates a curated Scenario Bank theme per ISO week; free users get the featured taste, Pro gets the full pack (reuses `app.isPro`).
- Progress Journal: `JournalEntry` + `JournalStore` persist a row per completed session. AppState exposes `auraTrend`, `dimensionTrend`, `weekOverWeekDelta`, `dimensionBests`, `coachMemoryLine`, and `lastPersonalBest`. `JournalView` shows coach memory, Aura trend, WoW deltas, per-skill sparklines, PRs, and recent sessions. Reads existing score data only — no new source of truth.

### Surfacing wiring
- Profile: coach card (tap to switch) + a "Progress Journal" card that pushes `JournalView`.
- Personal-best alerts surface as a global `PersonalBestToast` overlay on `MainTabView`, auto-dismissing after a celebratory beat + success haptic, so a new high fires regardless of which tab completed the session.

### Notes
- Superwall is integrated via `CharmsterSuperwall`; `SuperwallKit` links at build time (standalone typecheck reports "no such module 'SuperwallKit'" — expected, not a code error).
- App commits to a dark theme via `Theme.bg` (no global `preferredColorScheme`).