// Seed Charmster RAG knowledge base. Idempotent via natural_key = sha256(content|node|chunk_type|mode).
// Run: POST with empty body. Re-running is safe — existing rows are skipped.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type Strength = "peer_reviewed" | "practitioner" | "trend";
type Handling = "finding_cite" | "open_access" | "paraphrase_only" | "original";
type Mode = "hype_man" | "wingman" | "hard_truth" | null;
type ChunkType = "skill" | "science" | "claim" | "practice" | "coach_line";
type Node =
  | "first_impressions" | "conversation_flow" | "deep_connection"
  | "reading_signals" | "body_presence" | "handling_rejection" | "personalization";

interface Chunk {
  content: string;
  roadmap_node: Node;
  claim_strength: Strength;
  coach_mode: Mode;
  source_handling: Handling;
  source_citation: string | null;
  chunk_type: ChunkType;
}

const CHUNKS: Chunk[] = [
  // ===== NODE 1: first_impressions =====
  { content: "Start strong, lower the other person's risk of replying, and signal warmth + confidence fast.", roadmap_node: "first_impressions", claim_strength: "practitioner", coach_mode: null, source_handling: "original", source_citation: "Charmster", chunk_type: "skill" },
  { content: "Mere exposure, similarity, proximity and reciprocity are repeatedly identified as core drivers of early interpersonal attraction.", roadmap_node: "first_impressions", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Interpersonal attraction reviews", chunk_type: "science" },
  { content: "Expansive, open posture raises perceived dominance and dating desirability at zero acquaintance.", roadmap_node: "first_impressions", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "PMC nonverbal study", chunk_type: "science" },
  { content: "Specificity beats generic openers: referencing one concrete detail signals real attention and lowers reply risk.", roadmap_node: "first_impressions", claim_strength: "practitioner", coach_mode: null, source_handling: "paraphrase_only", source_citation: "Ury (concept, re-expressed)", chunk_type: "science" },
  { content: "Messages that reference a specific detail from someone's profile outperform generic hellos — specificity signals genuine attention.", roadmap_node: "first_impressions", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Online dating message research", chunk_type: "claim" },
  { content: "Openness in posture reads as confidence before a word is spoken.", roadmap_node: "first_impressions", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "PMC nonverbal study", chunk_type: "claim" },
  { content: "User submits an opener for a real profile; coach scores specificity, warmth, and effort, then rewrites it.", roadmap_node: "first_impressions", claim_strength: "practitioner", coach_mode: null, source_handling: "original", source_citation: "Charmster", chunk_type: "practice" },
  { content: "Okay that opener actually has a pulse — you noticed something real about them. Tighten one thing and it's money.", roadmap_node: "first_impressions", claim_strength: "practitioner", coach_mode: "hype_man", source_handling: "original", source_citation: "Charmster", chunk_type: "coach_line" },
  { content: "Solid start. Research on attraction says specificity signals real interest — let's swap the generic line for the detail you spotted in photo 3.", roadmap_node: "first_impressions", claim_strength: "practitioner", coach_mode: "wingman", source_handling: "original", source_citation: "Charmster", chunk_type: "coach_line" },
  { content: "This is a 'hey' with extra steps. It says nothing only you could've sent. Reference one specific thing — or expect silence.", roadmap_node: "first_impressions", claim_strength: "practitioner", coach_mode: "hard_truth", source_handling: "original", source_citation: "Charmster", chunk_type: "coach_line" },

  // ===== NODE 2: conversation_flow =====
  { content: "Sustain momentum through reciprocal, gradually deepening exchange.", roadmap_node: "conversation_flow", claim_strength: "practitioner", coach_mode: null, source_handling: "original", source_citation: "Charmster", chunk_type: "skill" },
  { content: "Social Penetration Theory: relationships deepen via graduated, mutual self-disclosure across breadth and depth.", roadmap_node: "conversation_flow", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Altman & Taylor 1973", chunk_type: "science" },
  { content: "Bids for connection: partners who turned toward bids stayed together ~86% of the time vs ~33% for those who divorced.", roadmap_node: "conversation_flow", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Gottman Institute", chunk_type: "science" },
  { content: "Closeness grows when disclosure is mutual and gradual — matching depth matters more than going deep fastest.", roadmap_node: "conversation_flow", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Altman & Taylor 1973", chunk_type: "claim" },
  { content: "Small attempts to connect ('bids') are the real currency of a conversation; noticing and answering them predicts whether it survives.", roadmap_node: "conversation_flow", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Gottman Institute", chunk_type: "claim" },
  { content: "Simulated conversation; coach flags missed bids and disclosure mismatches (too shallow / too fast).", roadmap_node: "conversation_flow", claim_strength: "practitioner", coach_mode: null, source_handling: "original", source_citation: "Charmster", chunk_type: "practice" },
  { content: "You caught their little joke and ran with it — that's exactly the move. Momentum is yours.", roadmap_node: "conversation_flow", claim_strength: "practitioner", coach_mode: "hype_man", source_handling: "original", source_citation: "Charmster", chunk_type: "coach_line" },
  { content: "They just made a bid for connection and you answered with a fact. Relationship research says match the energy — try mirroring the feeling, not just the info.", roadmap_node: "conversation_flow", claim_strength: "practitioner", coach_mode: "wingman", source_handling: "original", source_citation: "Charmster", chunk_type: "coach_line" },
  { content: "You went from weather to childhood trauma in two texts. Disclosure works when it's gradual and mutual — you skipped the ladder.", roadmap_node: "conversation_flow", claim_strength: "practitioner", coach_mode: "hard_truth", source_handling: "original", source_citation: "Charmster", chunk_type: "coach_line" },

  // ===== NODE 3: deep_connection =====
  { content: "Create genuine closeness through escalating, reciprocal questions.", roadmap_node: "deep_connection", claim_strength: "practitioner", coach_mode: null, source_handling: "original", source_citation: "Charmster", chunk_type: "skill" },
  { content: "Structured escalating self-disclosure (the '36 Questions') reliably generates interpersonal closeness between strangers.", roadmap_node: "deep_connection", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Aron et al. 1997", chunk_type: "science" },
  { content: "The 36-question list itself is openly available via Greater Good (UC Berkeley) and may be referenced directly.", roadmap_node: "deep_connection", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "open_access", source_citation: "Greater Good, UC Berkeley", chunk_type: "science" },
  { content: "A guided ramp of increasingly personal, reciprocal questions can manufacture real closeness — the mechanism is escalation + mutuality, not the exact words.", roadmap_node: "deep_connection", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Aron et al. 1997", chunk_type: "claim" },
  { content: "Coach offers a 'depth ladder' of questions tuned to where the conversation already is; scores whether the user reciprocated after asking.", roadmap_node: "deep_connection", claim_strength: "practitioner", coach_mode: null, source_handling: "original", source_citation: "Charmster", chunk_type: "practice" },
  { content: "That question went somewhere real — and you shared back. That's how strangers turn into something.", roadmap_node: "deep_connection", claim_strength: "practitioner", coach_mode: "hype_man", source_handling: "original", source_citation: "Charmster", chunk_type: "coach_line" },
  { content: "The closeness research is clear: ask, then share back at the same depth. You asked a great one — now give them yours.", roadmap_node: "deep_connection", claim_strength: "practitioner", coach_mode: "wingman", source_handling: "original", source_citation: "Charmster", chunk_type: "coach_line" },
  { content: "You're interviewing them. Closeness needs reciprocity — answer your own question before they feel like a suspect.", roadmap_node: "deep_connection", claim_strength: "practitioner", coach_mode: "hard_truth", source_handling: "original", source_citation: "Charmster", chunk_type: "coach_line" },

  // ===== NODE 4: reading_signals =====
  { content: "Read interest/discomfort probabilistically — without overclaiming.", roadmap_node: "reading_signals", claim_strength: "practitioner", coach_mode: null, source_handling: "original", source_citation: "Charmster", chunk_type: "skill" },
  { content: "Comfort vs discomfort, read against an individual's baseline, is a more honest framework than reading single isolated 'tells'.", roadmap_node: "reading_signals", claim_strength: "practitioner", coach_mode: null, source_handling: "paraphrase_only", source_citation: "Navarro (concept, re-expressed)", chunk_type: "science" },
  { content: "36 coded flirting behaviors map onto distinct flirting styles, indicating attraction is communicated through varied repertoires.", roadmap_node: "reading_signals", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Hall flirting-styles research", chunk_type: "science" },
  { content: "Many popular 'tell-tale signs' of attraction or deception are noisy and weaker than pop-culture claims suggest.", roadmap_node: "reading_signals", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Nonverbal signal-reliability research", chunk_type: "science" },
  { content: "Read clusters and changes from baseline, not single gestures.", roadmap_node: "reading_signals", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Nonverbal signal-reliability research", chunk_type: "claim" },
  { content: "Treat signals as probabilities, not proof — many classic 'tells' are unreliable on their own.", roadmap_node: "reading_signals", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Nonverbal signal-reliability research", chunk_type: "claim" },
  { content: "Coach presents a scenario; user guesses the signal; coach corrects toward probabilistic reading.", roadmap_node: "reading_signals", claim_strength: "practitioner", coach_mode: null, source_handling: "original", source_citation: "Charmster", chunk_type: "practice" },
  { content: "Nice read — you noticed they leaned in and re-engaged. That cluster is a green light.", roadmap_node: "reading_signals", claim_strength: "practitioner", coach_mode: "hype_man", source_handling: "original", source_citation: "Charmster", chunk_type: "coach_line" },
  { content: "One crossed arm isn't rejection. Look for clusters and shifts from their normal — that's what the research actually supports.", roadmap_node: "reading_signals", claim_strength: "practitioner", coach_mode: "wingman", source_handling: "original", source_citation: "Charmster", chunk_type: "coach_line" },
  { content: "You're mind-reading off one glance. The science says most single 'tells' are noise. Stop guessing certainty you don't have.", roadmap_node: "reading_signals", claim_strength: "practitioner", coach_mode: "hard_truth", source_handling: "original", source_citation: "Charmster", chunk_type: "coach_line" },

  // ===== NODE 5: body_presence =====
  { content: "Project grounded confidence through presence, warmth, and power.", roadmap_node: "body_presence", claim_strength: "practitioner", coach_mode: null, source_handling: "original", source_citation: "Charmster", chunk_type: "skill" },
  { content: "Charisma can be modeled as presence + warmth + power — three trainable ingredients, not an innate trait. Maps to the app's charisma score.", roadmap_node: "body_presence", claim_strength: "practitioner", coach_mode: null, source_handling: "paraphrase_only", source_citation: "Cabane (concept, re-expressed)", chunk_type: "science" },
  { content: "Expansive, open posture is associated with higher perceived confidence and desirability at zero acquaintance.", roadmap_node: "body_presence", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "PMC posture study", chunk_type: "science" },
  { content: "Charisma isn't innate — it's three trainable ingredients: being present, projecting warmth, and projecting competence.", roadmap_node: "body_presence", claim_strength: "practitioner", coach_mode: null, source_handling: "paraphrase_only", source_citation: "Cabane (concept, re-expressed)", chunk_type: "claim" },
  { content: "User records a short clip; vision model scores presence/warmth/power and gives one specific fix.", roadmap_node: "body_presence", claim_strength: "practitioner", coach_mode: null, source_handling: "original", source_citation: "Charmster", chunk_type: "practice" },
  { content: "You held eye contact and actually smiled — presence + warmth, two of the three. You're close.", roadmap_node: "body_presence", claim_strength: "practitioner", coach_mode: "hype_man", source_handling: "original", source_citation: "Charmster", chunk_type: "coach_line" },
  { content: "Charisma breaks into presence, warmth, and power. You've got warmth — let's add stillness so you read as grounded.", roadmap_node: "body_presence", claim_strength: "practitioner", coach_mode: "wingman", source_handling: "original", source_citation: "Charmster", chunk_type: "coach_line" },
  { content: "You're fidgeting and looking away — that reads as low power. Plant your feet, slow down, hold the gaze a beat longer.", roadmap_node: "body_presence", claim_strength: "practitioner", coach_mode: "hard_truth", source_handling: "original", source_citation: "Charmster", chunk_type: "coach_line" },

  // ===== NODE 6: handling_rejection =====
  { content: "Reframe rejection, kill neediness, build resilience.", roadmap_node: "handling_rejection", claim_strength: "practitioner", coach_mode: null, source_handling: "original", source_citation: "Charmster", chunk_type: "skill" },
  { content: "Non-neediness and outcome independence: attaching your worth to one outcome is what creates the needy pattern; loosening that grip makes you both more attractive and less anxious.", roadmap_node: "handling_rejection", claim_strength: "practitioner", coach_mode: null, source_handling: "paraphrase_only", source_citation: "Manson (concept, re-expressed)", chunk_type: "science" },
  { content: "CBT cognitive reframing combined with graded exposure reliably reduces social fear in social anxiety populations.", roadmap_node: "handling_rejection", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "CBT / social-anxiety literature", chunk_type: "science" },
  { content: "Safety behaviors on dates (over-rehearsing lines, avoiding eye contact, drinking to relax) maintain anxiety and worsen outcomes for anxious daters.", roadmap_node: "handling_rejection", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Safety-behaviors research", chunk_type: "science" },
  { content: "Avoidance and 'safety behaviors' (over-rehearsing, not making eye contact) keep anxiety alive — gradual exposure shrinks it.", roadmap_node: "handling_rejection", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Safety-behaviors research", chunk_type: "claim" },
  { content: "Neediness comes from attaching your worth to one outcome; lowering the stakes makes you more attractive and feel better.", roadmap_node: "handling_rejection", claim_strength: "practitioner", coach_mode: null, source_handling: "paraphrase_only", source_citation: "Manson (concept, re-expressed)", chunk_type: "claim" },
  { content: "Reframe drills — user logs a rejection; coach guides a CBT-style reframe and a small next-exposure step.", roadmap_node: "handling_rejection", claim_strength: "practitioner", coach_mode: null, source_handling: "original", source_citation: "Charmster", chunk_type: "practice" },
  { content: "One no doesn't define you — you put yourself out there, which most people never do. Next.", roadmap_node: "handling_rejection", claim_strength: "practitioner", coach_mode: "hype_man", source_handling: "original", source_citation: "Charmster", chunk_type: "coach_line" },
  { content: "That sting is your brain over-weighting one outcome. CBT calls this a thinking trap — let's reframe it and line up the next small rep.", roadmap_node: "handling_rejection", claim_strength: "practitioner", coach_mode: "wingman", source_handling: "original", source_citation: "Charmster", chunk_type: "coach_line" },
  { content: "You're spiraling over one person who barely knew you. That's outcome-dependence. The fix isn't reassurance — it's the next conversation.", roadmap_node: "handling_rejection", claim_strength: "practitioner", coach_mode: "hard_truth", source_handling: "original", source_citation: "Charmster", chunk_type: "coach_line" },

  // ===== NODE 7: personalization =====
  { content: "Adapt coaching to the user's attachment patterns (the engine behind the assessment quiz).", roadmap_node: "personalization", claim_strength: "practitioner", coach_mode: null, source_handling: "original", source_citation: "Charmster", chunk_type: "skill" },
  { content: "Adult attachment theory describes anxious, avoidant, and secure tendencies that systematically shape dating behavior and reactions to closeness.", roadmap_node: "personalization", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Fraley attachment overview", chunk_type: "science" },
  { content: "Attachment styles can change with new relational experiences — important framing for a growth-oriented app.", roadmap_node: "personalization", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Levine / Columbia", chunk_type: "science" },
  { content: "Attachment style shapes dating behavior — but it's not a fixed sentence; it can move toward secure with the right experiences.", roadmap_node: "personalization", claim_strength: "peer_reviewed", coach_mode: null, source_handling: "finding_cite", source_citation: "Levine / Columbia", chunk_type: "claim" },
  { content: "Onboarding quiz infers a tendency; coach tone + lesson emphasis adapt (reassurance-pacing for anxious, encouragement-to-engage for avoidant).", roadmap_node: "personalization", claim_strength: "practitioner", coach_mode: null, source_handling: "original", source_citation: "Charmster", chunk_type: "practice" },
  { content: "You leaned into the discomfort instead of ghosting — that's secure behavior, and it's a muscle you're building.", roadmap_node: "personalization", claim_strength: "practitioner", coach_mode: "hype_man", source_handling: "original", source_citation: "Charmster", chunk_type: "coach_line" },
  { content: "This reads like an anxious-attachment moment — the urge to double-text. Research says the style can shift; let's practice the secure response.", roadmap_node: "personalization", claim_strength: "practitioner", coach_mode: "wingman", source_handling: "original", source_citation: "Charmster", chunk_type: "coach_line" },
  { content: "Pulling away the second it got real is avoidant. It's a pattern, not a personality — but only if you actually work it.", roadmap_node: "personalization", claim_strength: "practitioner", coach_mode: "hard_truth", source_handling: "original", source_citation: "Charmster", chunk_type: "coach_line" },
];

async function sha256(s: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, "0")).join("");
}

async function embed(text: string, apiKey: string): Promise<number[]> {
  const res = await fetch("https://api.openai.com/v1/embeddings", {
    method: "POST",
    headers: { "Authorization": `Bearer ${apiKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({ model: "text-embedding-3-small", input: text }),
  });
  if (!res.ok) throw new Error(`embed failed: ${await res.text()}`);
  const json = await res.json();
  return json.data[0].embedding;
}

Deno.serve(async (_req) => {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const openaiKey = Deno.env.get("OPENAI_API_KEY")!;
    const sb = createClient(supabaseUrl, serviceKey);

    // Stable order: 🟢 finding_cite/open_access/original first, then 🟡 paraphrase_only.
    const ordered = [...CHUNKS].sort((a, b) => {
      const pri = (c: Chunk) => c.source_handling === "paraphrase_only" ? 1 : 0;
      return pri(a) - pri(b);
    });

    let inserted = 0, skipped = 0;
    for (const c of ordered) {
      const key = await sha256(`${c.content}|${c.roadmap_node}|${c.chunk_type}|${c.coach_mode ?? "none"}`);
      const { data: existing } = await sb.from("knowledge_chunks").select("id").eq("natural_key", key).maybeSingle();
      if (existing) { skipped++; continue; }
      const embedding = await embed(c.content, openaiKey);
      const { error } = await sb.from("knowledge_chunks").insert({
        content: c.content,
        embedding,
        roadmap_node: c.roadmap_node,
        claim_strength: c.claim_strength,
        coach_mode: c.coach_mode,
        source_handling: c.source_handling,
        source_citation: c.source_citation,
        chunk_type: c.chunk_type,
        natural_key: key,
      });
      if (error) throw error;
      inserted++;
    }

    return new Response(JSON.stringify({ ok: true, inserted, skipped, total: CHUNKS.length }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), {
      status: 500, headers: { "Content-Type": "application/json" },
    });
  }
});