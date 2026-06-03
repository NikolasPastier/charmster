## Charmster AI: Dating Coach

A gamified, AI-powered social confidence and dating coach simulator. Duolingo-style roadmap of quests + AI-driven conversation practice (text screenshot analysis + live voice sim) + Boss Fights. Judgment-free skill-building sandbox, not a pickup-line generator.

**Tagline:** Practice the real thing.
**Bundle ID:** com.charmster.app

## Target Audience & Core Driver
- Men and women, 18–34 (Gen Z + younger Millennials)
- Experience social anxiety, dating app fatigue, or want to become more confident in person
- **Maslow driver:** Esteem + Belongingness — building real self-worth and social capability
- **Core action:** Complete a quest (text mission, voice sim, or boss fight) and earn XP
- **North Star metric:** Quests completed per active user per week
- **K-factor hooks:** Charm Score share card, streak flex, boss fight victory share (future scope)

## Visual Direction
- Dark mode only — premium self-improvement vibe
- Reference DNA: Duolingo path mechanics × Headspace calm premium × high-end fitness app polish
- **Background:** #0D0D0D (obsidian black)
- **Surface:** #1A1A1A
- **Border/Divider:** #2A2A2A
- **Primary text:** #FFFFFF
- **Secondary text:** #A0A0A0
- **Accent (XP / CTA / progress / unlocks):** #00E676 emerald green
- **Accent 2 (Boss Fights / streak / urgency):** #FF5E62 coral
- Typography: bold modern headers, approachable body
- Mapped style: `dark` with `game-ui` mechanics layered in

## v1 Scope — Screens
1. **Onboarding** — 3 slides + 4-question coach quiz + personalized Charm Score reveal (34/100) with progress ring
2. **Roadmap Home** — Duolingo-style snaking path: 4 sections (Beginner / Conversation / Confidence / Mastery), 10 nodes + 3 Boss Fights + Leaderboard unlock. Top bar with avatar, streak, XP.
3. **Quest Detail Bottom Sheet** — Title, description, XP/time/skill pills, content preview, Start Quest CTA (coral variant for Boss Fights)
4. **Text Mission Mode** — Screenshot upload → "Conversation Autopsy" with 3 score bars → coach feedback card → 3 reply templates in selected coach voice → +50 XP banner
5. **Voice Simulation Room** — Abstract animated orb avatar, live transcript, mic + end-call controls → scorecard (Charisma / Listening / Flow + overall Charm Score) → +75 XP
6. **Profile & Progress** — Avatar, level badge, stats row, coach mode toggle, achievement badge grid, weekly bar chart
7. **Paywall** — Premium dark layout, feature checkmarks, monthly/yearly toggle, 3-day free trial CTA — rendered via Superwall
8. **Settings** — Coach mode, notifications, account, subscription, legal, sign out

**Build priority (per brief):** 1 → 2 → 3 → 4 → 7 → 6 → 5 → 8. Screens 1–4 ship the MVP.

## Onboarding Choice
`personalization-quiz` — 3 intro slides + 4-question coach quiz + personalized Charm Score reveal. Paywall is shown later when the user hits a locked feature (not paywall-first), per the spec.

## UX Patterns to Mirror
- **Duolingo** — snaking lesson path, node states (locked / active pulsing / completed glow / boss), top streak+XP bar, section headers per path
- **Headspace** — premium dark surfaces, restrained typography, calm motion, abstract orb visuals for the voice room
- **High-end fitness (Centr / Ladder / Future)** — scorecard rings, weekly activity chart, premium paywall composition

## Data Model (Supabase)
- `profiles` — id, username, coach_mode (hype_man | wingman | hard_truth, default wingman), xp, streak, last_active, subscription_tier (free | basic | pro)
- `quests` — id, title, description, path (beginner | conversation | confidence | mastery), order_index, xp_reward, is_boss_fight
- `user_quest_progress` — user_id, quest_id, status (locked | unlocked | completed), score, completed_at
- `sessions` — id, user_id, session_type (text_mission | voice_sim | boss_fight), quest_id, messages (jsonb), scorecard (jsonb), ai_feedback, created_at

## Integrations
- **Supabase** — Auth (email/password + Apple Sign In) + Postgres for all tables above
- **Superwall** — Paywall display, A/B testing, subscription state. Tiers: Basic $19/mo, Pro $29/mo, Annual Pro $199/yr, all with 3-day free trial
- **OpenAI** — GPT-4o for Text Mission screenshot analysis + coach feedback + reply templates; Realtime API for the live Voice Simulation Room. Proxied through a Supabase Edge Function so the key stays server-side.
- **Push notifications** — Daily streak reminder, user-selectable time

## AI Coach System Prompt
Locked per brief. Three coach modes (Hype Man / Wingman / Hard Truth) interpolated into the system prompt along with XP, completed quests, and quiz weak areas. Feedback under 150 words, always ends with one specific actionable next step, no filler affirmations.

## Non-Goals (v1)
- No realistic AI face avatars — keep voice sim orb abstract
- No social feed / public leaderboard at launch (Leaderboard node is a teaser unlock)
- No body language video analysis at launch (listed in paywall as "coming soon")
- No Android, no web companion

## Pre-Build Confirmation
- **App name:** Charmster AI: Dating Coach
- **Bundle ID:** com.charmster.app
- **Design direction:** Dark premium (obsidian + emerald + coral), Duolingo-path mechanics, Headspace polish
- **Palette tokens:** bg `#0D0D0D` · surface `#1A1A1A` · border `#2A2A2A` · text `#FFFFFF` · secondary `#A0A0A0` · accent `#00E676` · accent-2 `#FF5E62`
- **Onboarding:** 3 slides + 4-question quiz + Charm Score reveal (personalization-quiz)
- **MVP screens to ship first:** Onboarding → Roadmap → Quest Detail Sheet → Text Mission Mode → Paywall
- **Then:** Profile/Progress → Voice Simulation Room → Settings
- **Data stance:** Build the iOS client with realistic mock data first (seeded quests, fake XP/streak, mocked AI responses). Wire Supabase + Superwall + OpenAI (via Supabase Edge Function) immediately after — all three are saved as project dependencies.
- **Excluded from v1:** body language video analysis, public leaderboard, social sharing surfaces, Android/web