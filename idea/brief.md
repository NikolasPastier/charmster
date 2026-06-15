## Charmster

AI-powered private coaching app to practice love and build conversational confidence, with avatar-based practice partners (looks + voice previews loaded from Supabase Storage).

### Current state
- Unified brand identity: a single reusable `CharmsterLogo` component streams the one transparent `Charmster Logo.png` (flaming heart + CHARMSTER wordmark) from the public Supabase `App logo` bucket. It renders at a fixed point height with `.scaledToFit()` so the aspect ratio is always preserved and never stretched, sits cleanly on light and dark backgrounds, caches via URLCache, and has a loading placeholder + heart/text fallback.
- The logo appears on the launch/splash screen (centered, fade-in), the onboarding/welcome hero, and the Path tab top header.
- App icon is generated from the heart emblem alone (no wordmark) at 1024×1024 with all required iOS sizes.

### Integrations
- Supabase configured (auth + DB + Storage). Brand logo, avatar stills, and voice previews stream from public buckets with mock-safe fallbacks.