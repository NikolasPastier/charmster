## Charmster AI — App Plan

Native iOS SwiftUI dating-confidence coach. `@Observable AppState` runtime model, `SettingsStore` (UserDefaults) persistence, Supabase (DB + Storage) backend, Superwall paywall. Curriculum-driven lessons with live AI practice sessions, scoring, journal, and a personalized onboarding quiz.

### Identity model
- **AI partner** (practice persona): `AvatarPersona` / `AvatarView` / `PartnerStillImage` — the simulated person the user practices with. Separate system, untouched. Shown only in "Practicing with..." contexts.
- **Human user**: `PersonalizationProfile` (name, username, goal, etc.). The user's own display name is single-sourced from the account step.

### User profile photo (shipped)
- The human's own optional profile photo, set in onboarding (AccountStep) and editable in Settings.
- One reusable identity surface: `UserAvatarView` (cached image → remote public URL → initials-on-aura / silhouette fallback) + `UserAvatarPicker` (PhotosPicker + save/remove).
- `UserAvatarStore`: local JPEG cache as display source of truth (instant/offline/pre-auth) + best-effort upload to public `user-avatars` Supabase bucket; path stored on `profile.profilePhotoPath`.
- Display surfaces now wired consistently:
  - **ProfileView header** uses `UserAvatarView` (was `BrandLogo`).
  - **Onboarding "plan ready" hero** leads with the user's `UserAvatarView`; the AI partner appears separately in a small "Practicing with {name}" chip with the AI look thumbnail — never the user's photo.
  - Settings + AccountStep editable picker.

### Backend state
- `profiles.profile_photo_path` column added.
- Public `user-avatars` Storage bucket + RLS (public read; bucket-scoped write for current pre-auth state).
- Real auth is still TODO; uploads currently key on `userId = "preview-user"`. Once auth lands, the same code keys per real user and enables cross-device avatar sync with no UI changes.