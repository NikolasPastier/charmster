// supabase/functions/seed_knowledge/index.ts
// Idempotent RAG seeder for Charmster AI. Re-runnable; upserts on natural_key.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const OPENAI_KEY = Deno.env.get("OPENAI_API_KEY")!;
const EMBED_MODEL = "text-embedding-3-small";

type Strength = "peer_reviewed" | "practitioner" | "trend";
type Handling = "finding_cite" | "open_access" | "paraphrase_only" | "original";
type Mode = "hype_man" | "wingman" | "hard_truth" | null;
type Kind = "skill" | "science" | "claim" | "practice" | "coach_line";

interface Chunk {
  content: string;
  roadmap_node: string;
  claim_strength: Strength;
  coach_mode: Mode;
  source_handling: Handling;
  source_citation: string | null;
  chunk_type: Kind;
}

const CHUNKS: Chunk[] = [
  // ---------- NODE 1: first_impressions ----------
  { roadmap_node: "first_impressions", chunk_type: "skill", claim_strength: "practitioner", coach_mode: null, source_handling: "original", source_citation: null,
    content: "Start strong, lower the other person's risk of replying, and signal warmth + confidence fast." },
  { roadmap_node: "first_impressions", chunk_type: "science", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Interpersonal attraction reviews",
    content: "Mere exposure, similarity, proximity and reciprocity drive early attraction." },
  { roadmap_node: "first_impressions", chunk_type: "science", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "PMC nonverbal study",
    content: "Expansive, open posture raises perceived dominance and dating desirability at zero acquaintance." },
  { roadmap_node: "first_impressions", chunk_type: "science", claim_strength: "practitioner", coach_mode: null, source_handling: "paraphrase_only", source_citation: "Ury (concept, re-expressed)",
    content: "Specificity beats generic openers — referencing a concrete detail signals genuine attention rather than mass-messaging." },
  { roadmap_node: "first_impressions", chunk_type: "claim", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Interpersonal attraction reviews",
    content: "Messages that reference a specific detail from someone's profile outperform generic hellos — specificity signals genuine attention." },
  { roadmap_node: "first_impressions", chunk_type: "claim", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "PMC nonverbal study",
    content: "Openness in posture reads as confidence before a word is spoken." },
  { roadmap_node: "first_impressions", chunk_type: "practice", claim_strength: "practitioner", coach_mode: null, source_handling: "original", source_citation: null,
    content: "User submits an opener for a real profile; coach scores specificity, warmth, and effort, then rewrites it." },
  { roadmap_node: "first_impressions", chunk_type: "coach_line", claim_strength: "practitioner", coach_mode: "hype_man", source_handling: "original", source_citation: null,
    content: "Okay that opener actually has a pulse — you noticed something real about them. Tighten one thing and it's money." },
  { roadmap_node: "first_impressions", chunk_type: "coach_line", claim_strength: "peer_reviewed", coach_mode: "wingman", source_handling: "original", source_citation: null,
    content: "Solid start. Research on attraction says specificity signals real interest — let's swap the generic line for the detail you spotted in photo 3." },
  { roadmap_node: "first_impressions", chunk_type: "coach_line", claim_strength: "practitioner", coach_mode: "hard_truth", source_handling: "original", source_citation: null,
    content: "This is a 'hey' with extra steps. It says nothing only you could've sent. Reference one specific thing — or expect silence." },

  // ---------- NODE 2: conversation_flow ----------
  { roadmap_node: "conversation_flow", chunk_type: "skill", claim_strength: "practitioner", coach_mode: null, source_handling: "original", source_citation: null,
    content: "Sustain momentum through reciprocal, gradually deepening exchange." },
  { roadmap_node: "conversation_flow", chunk_type: "science", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Altman & Taylor 1973",
    content: "Social Penetration Theory — relationships deepen via graduated, mutual self-disclosure." },
  { roadmap_node: "conversation_flow", chunk_type: "science", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Gottman Institute",
    content: "Bids for connection — partners who turned toward bids stayed together ~86% of the time vs ~33% for those who divorced." },
  { roadmap_node: "conversation_flow", chunk_type: "claim", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Altman & Taylor 1973",
    content: "Closeness grows when disclosure is mutual and gradual — matching depth matters more than going deep fastest." },
  { roadmap_node: "conversation_flow", chunk_type: "claim", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Gottman Institute",
    content: "Small attempts to connect ('bids') are the real currency of a conversation; noticing and answering them predicts whether it survives." },
  { roadmap_node: "conversation_flow", chunk_type: "practice", claim_strength: "practitioner", coach_mode: null, source_handling: "original", source_citation: null,
    content: "Simulated conversation; coach flags missed bids and disclosure mismatches (too shallow / too fast)." },
  { roadmap_node: "conversation_flow", chunk_type: "coach_line", claim_strength: "practitioner", coach_mode: "hype_man", source_handling: "original", source_citation: null,
    content: "You caught their little joke and ran with it — that's exactly the move. Momentum is yours." },
  { roadmap_node: "conversation_flow", chunk_type: "coach_line", claim_strength: "peer_reviewed", coach_mode: "wingman", source_handling: "original", source_citation: null,
    content: "They just made a bid for connection and you answered with a fact. Relationship research says match the energy — try mirroring the feeling, not just the info." },
  { roadmap_node: "conversation_flow", chunk_type: "coach_line", claim_strength: "practitioner", coach_mode: "hard_truth", source_handling: "original", source_citation: null,
    content: "You went from weather to childhood trauma in two texts. Disclosure works when it's gradual and mutual — you skipped the ladder." },

  // ---------- NODE 3: deep_connection ----------
  { roadmap_node: "deep_connection", chunk_type: "skill", claim_strength: "practitioner", coach_mode: null, source_handling: "original", source_citation: null,
    content: "Create genuine closeness through escalating, reciprocal questions." },
  { roadmap_node: "deep_connection", chunk_type: "science", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Aron et al. 1997",
    content: "Structured escalating self-disclosure (the '36 Questions') reliably generates interpersonal closeness." },
  { roadmap_node: "deep_connection", chunk_type: "science", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "open_access", source_citation: "Greater Good, UC Berkeley",
    content: "The 36-question list itself is openly available and may be referenced directly." },
  { roadmap_node: "deep_connection", chunk_type: "claim", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Aron et al. 1997",
    content: "A guided ramp of increasingly personal, reciprocal questions can manufacture real closeness — the mechanism is escalation + mutuality, not the exact words." },
  { roadmap_node: "deep_connection", chunk_type: "practice", claim_strength: "practitioner", coach_mode: null, source_handling: "original", source_citation: null,
    content: "Coach offers a 'depth ladder' of questions tuned to where the conversation already is; scores whether the user reciprocated after asking." },
  { roadmap_node: "deep_connection", chunk_type: "coach_line", claim_strength: "practitioner", coach_mode: "hype_man", source_handling: "original", source_citation: null,
    content: "That question went somewhere real — and you shared back. That's how strangers turn into something." },
  { roadmap_node: "deep_connection", chunk_type: "coach_line", claim_strength: "peer_reviewed", coach_mode: "wingman", source_handling: "original", source_citation: null,
    content: "The closeness research is clear: ask, then share back at the same depth. You asked a great one — now give them yours." },
  { roadmap_node: "deep_connection", chunk_type: "coach_line", claim_strength: "practitioner", coach_mode: "hard_truth", source_handling: "original", source_citation: null,
    content: "You're interviewing them. Closeness needs reciprocity — answer your own question before they feel like a suspect." },

  // ---------- NODE 4: reading_signals ----------
  { roadmap_node: "reading_signals", chunk_type: "skill", claim_strength: "practitioner", coach_mode: null, source_handling: "original", source_citation: null,
    content: "Read interest/discomfort probabilistically — without overclaiming." },
  { roadmap_node: "reading_signals", chunk_type: "science", claim_strength: "practitioner", coach_mode: null, source_handling: "paraphrase_only", source_citation: "Navarro (concept, re-expressed)",
    content: "Comfort vs discomfort and baselining framework — read shifts away from a person's normal as data, not isolated gestures." },
  { roadmap_node: "reading_signals", chunk_type: "science", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Hall flirting-styles research",
    content: "36 coded flirting behaviors across distinct flirting styles." },
  { roadmap_node: "reading_signals", chunk_type: "science", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Nonverbal signal-reliability research",
    content: "Many popular 'tell-tale signs' are noisy and weaker than pop-culture claims." },
  { roadmap_node: "reading_signals", chunk_type: "claim", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Nonverbal signal-reliability research",
    content: "Read clusters and changes from baseline, not single gestures." },
  { roadmap_node: "reading_signals", chunk_type: "claim", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Nonverbal signal-reliability research",
    content: "Treat signals as probabilities, not proof — many classic 'tells' are unreliable on their own." },
  { roadmap_node: "reading_signals", chunk_type: "practice", claim_strength: "practitioner", coach_mode: null, source_handling: "original", source_citation: null,
    content: "Coach presents a scenario; user guesses the signal; coach corrects toward probabilistic reading." },
  { roadmap_node: "reading_signals", chunk_type: "coach_line", claim_strength: "practitioner", coach_mode: "hype_man", source_handling: "original", source_citation: null,
    content: "Nice read — you noticed they leaned in and re-engaged. That cluster is a green light." },
  { roadmap_node: "reading_signals", chunk_type: "coach_line", claim_strength: "peer_reviewed", coach_mode: "wingman", source_handling: "original", source_citation: null,
    content: "One crossed arm isn't rejection. Look for clusters and shifts from their normal — that's what the research actually supports." },
  { roadmap_node: "reading_signals", chunk_type: "coach_line", claim_strength: "practitioner", coach_mode: "hard_truth", source_handling: "original", source_citation: null,
    content: "You're mind-reading off one glance. The science says most single 'tells' are noise. Stop guessing certainty you don't have." },

  // ---------- NODE 5: body_presence ----------
  { roadmap_node: "body_presence", chunk_type: "skill", claim_strength: "practitioner", coach_mode: null, source_handling: "original", source_citation: null,
    content: "Project grounded confidence through presence, warmth, and power." },
  { roadmap_node: "body_presence", chunk_type: "science", claim_strength: "practitioner", coach_mode: null, source_handling: "paraphrase_only", source_citation: "Cabane (concept, re-expressed)",
    content: "Charisma = presence + warmth + power; framework concept re-expressed, maps to the app's charisma score." },
  { roadmap_node: "body_presence", chunk_type: "science", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "PMC posture study",
    content: "Expansive/open posture research on perceived confidence and desirability." },
  { roadmap_node: "body_presence", chunk_type: "claim", claim_strength: "practitioner", coach_mode: null, source_handling: "paraphrase_only", source_citation: "Cabane (concept, re-expressed)",
    content: "Charisma isn't innate — it's three trainable ingredients: being present, projecting warmth, and projecting competence." },
  { roadmap_node: "body_presence", chunk_type: "practice", claim_strength: "practitioner", coach_mode: null, source_handling: "original", source_citation: null,
    content: "User records a clip; vision model scores presence/warmth/power and gives one fix." },
  { roadmap_node: "body_presence", chunk_type: "coach_line", claim_strength: "practitioner", coach_mode: "hype_man", source_handling: "original", source_citation: null,
    content: "You held eye contact and actually smiled — presence + warmth, two of the three. You're close." },
  { roadmap_node: "body_presence", chunk_type: "coach_line", claim_strength: "practitioner", coach_mode: "wingman", source_handling: "original", source_citation: null,
    content: "Charisma breaks into presence, warmth, and power. You've got warmth — let's add stillness so you read as grounded." },
  { roadmap_node: "body_presence", chunk_type: "coach_line", claim_strength: "practitioner", coach_mode: "hard_truth", source_handling: "original", source_citation: null,
    content: "You're fidgeting and looking away — that reads as low power. Plant your feet, slow down, hold the gaze a beat longer." },

  // ---------- NODE 6: handling_rejection ----------
  { roadmap_node: "handling_rejection", chunk_type: "skill", claim_strength: "practitioner", coach_mode: null, source_handling: "original", source_citation: null,
    content: "Reframe rejection, kill neediness, build resilience." },
  { roadmap_node: "handling_rejection", chunk_type: "science", claim_strength: "practitioner", coach_mode: null, source_handling: "paraphrase_only", source_citation: "Manson (concept, re-expressed)",
    content: "Non-neediness and outcome independence — attaching worth to a single outcome amplifies the sting; loosening that attachment lowers anxiety and reads as more attractive." },
  { roadmap_node: "handling_rejection", chunk_type: "science", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "CBT / social-anxiety literature",
    content: "CBT cognitive reframing + exposure logic reduces social fear." },
  { roadmap_node: "handling_rejection", chunk_type: "science", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Safety-behaviors research",
    content: "Safety behaviors on dates undermine outcomes for anxious daters." },
  { roadmap_node: "handling_rejection", chunk_type: "claim", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Safety-behaviors research",
    content: "Avoidance and 'safety behaviors' (over-rehearsing, not making eye contact) keep anxiety alive — gradual exposure shrinks it." },
  { roadmap_node: "handling_rejection", chunk_type: "claim", claim_strength: "practitioner", coach_mode: null, source_handling: "paraphrase_only", source_citation: "Manson (concept, re-expressed)",
    content: "Neediness comes from attaching your worth to one outcome; lowering the stakes makes you more attractive and feel better." },
  { roadmap_node: "handling_rejection", chunk_type: "practice", claim_strength: "practitioner", coach_mode: null, source_handling: "original", source_citation: null,
    content: "Reframe drills — user logs a rejection; coach guides a CBT-style reframe and a small next-exposure step." },
  { roadmap_node: "handling_rejection", chunk_type: "coach_line", claim_strength: "practitioner", coach_mode: "hype_man", source_handling: "original", source_citation: null,
    content: "One no doesn't define you — you put yourself out there, which most people never do. Next." },
  { roadmap_node: "handling_rejection", chunk_type: "coach_line", claim_strength: "peer_reviewed", coach_mode: "wingman", source_handling: "original", source_citation: null,
    content: "That sting is your brain over-weighting one outcome. CBT calls this a thinking trap — let's reframe it and line up the next small rep." },
  { roadmap_node: "handling_rejection", chunk_type: "coach_line", claim_strength: "practitioner", coach_mode: "hard_truth", source_handling: "original", source_citation: null,
    content: "You're spiraling over one person who barely knew you. That's outcome-dependence. The fix isn't reassurance — it's the next conversation." },

  // ---------- NODE 7: personalization ----------
  { roadmap_node: "personalization", chunk_type: "skill", claim_strength: "practitioner", coach_mode: null, source_handling: "original", source_citation: null,
    content: "Adapt coaching to the user's attachment patterns (the engine behind the assessment quiz)." },
  { roadmap_node: "personalization", chunk_type: "science", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Fraley attachment overview",
    content: "Adult attachment theory — anxious / avoidant / secure tendencies shape dating behavior." },
  { roadmap_node: "personalization", chunk_type: "science", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Levine / Columbia",
    content: "Attachment styles can change — critical framing for a growth app." },
  { roadmap_node: "personalization", chunk_type: "claim", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Fraley attachment overview",
    content: "Attachment style shapes dating behavior — but it's not a fixed sentence; it can move toward secure with the right experiences." },
  { roadmap_node: "personalization", chunk_type: "practice", claim_strength: "practitioner", coach_mode: null, source_handling: "original", source_citation: null,
    content: "Onboarding quiz infers a tendency; coach tone + lesson emphasis adapt (reassurance-pacing for anxious, encouragement-to-engage for avoidant)." },
  { roadmap_node: "personalization", chunk_type: "coach_line", claim_strength: "practitioner", coach_mode: "hype_man", source_handling: "original", source_citation: null,
    content: "You leaned into the discomfort instead of ghosting — that's secure behavior, and it's a muscle you're building." },
  { roadmap_node: "personalization", chunk_type: "coach_line", claim_strength: "peer_reviewed", coach_mode: "wingman", source_handling: "original", source_citation: null,
    content: "This reads like an anxious-attachment moment — the urge to double-text. Research says the style can shift; let's practice the secure response." },
  { roadmap_node: "personalization", chunk_type: "coach_line", claim_strength: "practitioner", coach_mode: "hard_truth", source_handling: "original", source_citation: null,
    content: "Pulling away the second it got real is avoidant. It's a pattern, not a personality — but only if you actually work it." },
];

async function sha256(s: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, "0")).join("");
}

async function embed(text: string): Promise<number[]> {
  const r = await fetch("https://api.openai.com/v1/embeddings", {
    method: "POST",
    headers: { "Authorization": `Bearer ${OPENAI_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ model: EMBED_MODEL, input: text }),
  });
  if (!r.ok) throw new Error(`embed failed: ${r.status} ${await r.text()}`);
  const j = await r.json();
  return j.data[0].embedding;
}

Deno.serve(async (_req) => {
  try {
    const sb = createClient(SUPABASE_URL, SERVICE_KEY);
    // Order: peer_reviewed/open_access/original first, then paraphrase_only
    const sorted = [...CHUNKS].sort((a, b) =>
      (a.source_handling === "paraphrase_only" ? 1 : 0) -
      (b.source_handling === "paraphrase_only" ? 1 : 0)
    );

    let inserted = 0, skipped = 0;
    for (const c of sorted) {
      const natural_key = await sha256(`${c.content}|${c.roadmap_node}|${c.chunk_type}|${c.coach_mode ?? ""}`);
      const { data: existing } = await sb.from("knowledge_chunks").select("id").eq("natural_key", natural_key).maybeSingle();
      if (existing) { skipped++; continue; }
      const vec = await embed(c.content);
      const { error } = await sb.from("knowledge_chunks").insert({
        natural_key,
        content: c.content,
        embedding: vec as unknown as string, // pgvector accepts array via supabase-js
        roadmap_node: c.roadmap_node,
        claim_strength: c.claim_strength,
        coach_mode: c.coach_mode,
        source_handling: c.source_handling,
        source_citation: c.source_citation,
        chunk_type: c.chunk_type,
      });
      if (error) throw error;
      inserted++;
    }
    return new Response(JSON.stringify({ ok: true, inserted, skipped, total: CHUNKS.length }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});