## Charmster — App Plan

Charmster is a dating/social-skills coaching app where users "join a coach's team" — named coach characters (Theo, Dr. Ray, Cole, Noah, Leo) that drive practice, debriefs, and nudges in their own voice. Supabase (auth + DB + Storage) is connected; coach/avatar media streams from the public `Avatars` bucket. Superwall handles monetization.

### Recently shipped
- **Coach preview-line auto-play**: Selecting a coach in onboarding (or the gallery) now auto-plays that coach's three voice preview lines in strict order 1 → 2 → 3, then stops. Implemented via a reusable `CoachPreviewPlayer` (AVQueuePlayer-based, `.playback` session, interruption/route/background handling, debounced re-taps, per-line failure skip) and a single `CoachPreviewLineURL` helper that URL-encodes the spaced Supabase Storage paths. The previewing coach card shows an animated sound-wave badge.

### Architecture notes
- Coach personas: `Models/CoachPersona.swift` (now exposes `previewLines: [URL]`).
- Coach media URLs: `Services/CoachClipCatalog.swift` (clips/stills), `Services/CoachPreviewLineURL.swift` (voice preview lines).
- Audio players: `Services/AvatarVoicePreviewPlayer.swift` (partner voice, ambient) and `Services/CoachPreviewPlayer.swift` (coach intro voice, playback).
- Onboarding/gallery surface: `Views/CoachGalleryView.swift`, embedded in `Views/OnboardingFlowView.swift`.