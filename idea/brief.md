## Charmster AI: Dating Coach

A gamified, AI-powered social confidence and dating coach simulator. Science-based curriculum path + AI-driven conversation practice (text screenshot analysis + live voice/video sim) + photoreal video-clip avatar. Judgment-free skill-building sandbox, not a pickup-line generator.

**Tagline:** Practice love. Build real confidence.
**Bundle ID:** com.charmster.app

## Target Audience & Core Driver
- Men and women, 18–34 (Gen Z + younger Millennials)
- Experience social anxiety, dating app fatigue, or want to become more confident in person
- **Maslow driver:** Esteem + Belongingness — building real self-worth and social capability
- **Core action:** Complete a lesson / live practice session and move Aura
- **North Star metric:** Practice sessions completed per active user per week
- **Progression metric:** Aura (0–100 rolling average) — the XP/Level system was removed

## Visual Direction
- Dark, cinematic "noir-tech" base (#0B0910) lit by a warm love-spectrum aura gradient (purple→pink→red→orange→gold)
- Reference DNA: Duolingo path mechanics × Headspace calm premium × high-end fitness polish
- Score scale gradient (cool→warm): #4C8DFF → #8A5CFF → #FF4D94 → #FFC23D
- Mapped style: `dark` with `game-ui` mechanics layered in

## Onboarding (current)
First-run flow is the optimal-order personalization quiz (`personalization-quiz`), free and pre-paywall:
1 Hero (single consolidated hero, benefit rows, Aura glow) · 2 Goal (sets recommended start track) · 3 Experience (→ difficulty tier) · 4 Where you freeze (multi → focus areas) · 5 Confidence slider · 6 Coach style (all 5: Big Brother / Scientist / Alpha Mentor / Therapist / Wingman) · 7 Attachment 6-item + flirting (skippable, secure-leaning defaults) · 8 Daily goal + opt-in reminder (OS permission only on opt-in) · 9 Name + pick avatar look · 10 Privacy + cam/mic primer (no permission request here) · 11 Account + 17+ gate · 12 Personalized plan (growth-framed payoff, chosen avatar + Aura glow + recommended track + "why this fits") · 13 Free taster live session → paywall (`onboarding_complete`).

All captured preferences persist via `SettingsStore` and are editable later in Settings (per-answer + "Redo personalization"). The personalization profile feeds `coachPersonalizationSummary`, which is passed to the `coach` edge function for the AI system prompt.

Goal → start-track mapping: Date with intention → Deep Connection (7); Date casually → Humor/Banter (4); Get unstuck → Confidence/Anxiety (8); Confidence in general → Presence (6); fallback → Foundations (1).

## v1 Scope — Screens
1. Onboarding (above)
2. Roadmap Home — snaking path across 17 tracks with capstones + access-tier locks
3. Lecture Detail Sheet
4. Text Mission Mode — screenshot autopsy + coach feedback + reply templates
5. Live Practice Room — photoreal video-clip avatar, reactive Aura glow, Atmosphere meter, captions, post-session scorecard
6. Profile & Progress — Aura tier, stats, coach toggle, badges, weekly chart
7. Paywall — rendered via Superwall
8. Settings — full personalization editing (incl. avatar look/name), coaching, reminders, privacy, membership

## Data Model (Supabase)
- `profiles` — id, username, coach_mode, aura, streak, last_active, subscription_tier, personalization fields (goal, experience, confidence, flirting, attachment, avatar look/name, age confirm)
- `tracks` / `lectures` — canonical curriculum (seeded from manifest)
- `user_quest_progress` / `sessions` — progress + session records

## Integrations
- **Supabase** — Auth (email + Apple, not yet wired) + Postgres + Storage (avatar clips) + Edge Functions
- **Superwall** — paywall display/state; placement `onboarding_complete` fires after the free taster
- **OpenAI** — GPT for text analysis + coach feedback; Realtime API for live voice; proxied via Supabase Edge Functions
- **Push** — local daily streak reminder (opt-in during onboarding / Settings)

## Non-Goals (v1)
- No public leaderboard / social feed at launch
- No body-language video analysis at launch
- No Android, no web companion

## Data Stance
Local-first with realistic data; deterministic SplitMix64 mock retained strictly as the offline fallback for the live pipeline. Real Supabase auth + per-user personalization-profile persistence is the next milestone.