## Charmster — App Plan

Charmster is a dark, content-forward iOS app for practicing dating/social conversation skills with an AI avatar partner. Onboarding runs a personalization quiz, daily-goal setup, name + avatar selection, privacy primer, and account gate, then reveals a personalized plan and a free taster session before the Superwall paywall handoff.

### Data model
- `PersonalizationProfile` cleanly separates two name fields:
  - `name` → the user's own name (powers personalized headline + greetings + Settings "Name").
  - `avatarName` → the AI partner's name, default "Mia" (powers "Practicing with …", taster copy, Settings "Partner name").
- Prefs persist via `SettingsStore` (UserDefaults JSON).

### Recent changes
- Daily-reminder `DatePicker` on the "Set your daily goal" onboarding screen now forces `.environment(\.colorScheme, .dark)` so the compact time pill renders as light text on the dark chip (was near-black-on-dark and unreadable).
- Verified `name` and `avatarName` are distinct across onboarding, Settings, and practice screens — no swapping; no migration needed.

### Notes
- Superwall is integrated via `CharmsterSuperwall`; SuperwallKit links at build time.
- App commits to a dark theme via `Theme.bg` (no global `preferredColorScheme`).