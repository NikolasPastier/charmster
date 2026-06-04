// supabase/functions/coach/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const OPENAI_KEY = Deno.env.get("OPENAI_API_KEY")!;
const EMBED_MODEL = "text-embedding-3-small";
const CHAT_MODEL = "gpt-4o";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type Mode = "hype_man" | "wingman" | "hard_truth";

const PERSONAS: Record<Mode, string> = {
  hype_man: "You are the HYPE MAN coach: high-energy, affirming, momentum-focused. Celebrate effort, then give ONE tightening tip. Under 120 words. End with a concrete next move.",
  wingman: "You are the WINGMAN coach: balanced and explanatory. Reference the science only when a cited chunk is peer_reviewed. Give the why, then one concrete next move. Under 150 words.",
  hard_truth: "You are the HARD TRUTH coach: blunt, no sugar-coating. Name the mistake directly. Never cruel. Always actionable. Under 130 words. End with the exact next rep.",
};

async function embed(text: string): Promise<number[]> {
  const r = await fetch("https://api.openai.com/v1/embeddings", {
    method: "POST",
    headers: { "Authorization": `Bearer ${OPENAI_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ model: EMBED_MODEL, input: text }),
  });
  if (!r.ok) throw new Error(`embed failed: ${await r.text()}`);
  return (await r.json()).data[0].embedding;
}

interface RetrievedChunk {
  id: string;
  content: string;
  roadmap_node: string;
  claim_strength: string;
  coach_mode: string | null;
  source_handling: string;
  source_citation: string | null;
  chunk_type: string;
  similarity: number;
}

async function retrieveChunks(sb: any, query: string, roadmap_node: string, coach_mode: Mode, k = 6): Promise<RetrievedChunk[]> {
  const qv = await embed(query);
  const { data, error } = await sb.rpc("match_knowledge_chunks", {
    query_embedding: qv as unknown as string,
    match_node: roadmap_node,
    match_mode: coach_mode,
    match_count: k,
  });
  if (error) throw error;
  // Boost claim + coach_line ordering for live coaching
  const boosted = (data as RetrievedChunk[]).sort((a, b) => {
    const w = (c: RetrievedChunk) => (c.chunk_type === "claim" || c.chunk_type === "coach_line") ? 0.05 : 0;
    return (b.similarity + w(b)) - (a.similarity + w(a));
  });
  return boosted;
}

function buildSystemPrompt(mode: Mode, chunks: RetrievedChunk[]): string {
  const hasPeerReviewed = chunks.some(c => c.claim_strength === "peer_reviewed");
  const persona = PERSONAS[mode];
  const ctx = chunks.map((c, i) =>
    `[#${i + 1}] (${c.claim_strength}${c.source_citation ? `, cite: ${c.source_citation}` : ""}) ${c.content}`
  ).join("\n");
  return `${persona}

GROUNDING RULES:
- Use ONLY the retrieved knowledge below to ground your feedback.
- Do NOT invent statistics, percentages, or study findings.
- You may say "research shows", "studies find", or equivalent authority language ONLY if you are using a chunk tagged peer_reviewed. ${hasPeerReviewed ? "(At least one peer_reviewed chunk is available.)" : "(NO peer_reviewed chunks available — DO NOT use authority language. Use soft framing like 'a common coaching idea is…'.)"}
- Stay on the user's roadmap node; do not drift.
- Do not quote citations inline; the app surfaces them separately.

RETRIEVED KNOWLEDGE:
${ctx || "(no chunks retrieved)"}`;
}

async function chat(system: string, user: string): Promise<string> {
  const r = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: { "Authorization": `Bearer ${OPENAI_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      model: CHAT_MODEL,
      temperature: 0.7,
      messages: [{ role: "system", content: system }, { role: "user", content: user }],
    }),
  });
  if (!r.ok) throw new Error(`chat failed: ${await r.text()}`);
  return (await r.json()).choices[0].message.content as string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const body = await req.json();
    const { user_id, roadmap_node, user_input } = body;
    let coach_mode: Mode = body.coach_mode;
    if (!roadmap_node || !user_input) throw new Error("roadmap_node and user_input are required");

    const sb = createClient(SUPABASE_URL, SERVICE_KEY);

    if (!coach_mode && user_id) {
      const { data } = await sb.from("profiles").select("preferred_coach_mode").eq("user_id", user_id).maybeSingle();
      coach_mode = (data?.preferred_coach_mode as Mode) || "wingman";
    }
    coach_mode = coach_mode || "wingman";

    const chunks = await retrieveChunks(sb, user_input, roadmap_node, coach_mode);
    const system = buildSystemPrompt(coach_mode, chunks);
    const output = await chat(system, user_input);

    const citations = Array.from(new Set(chunks.map(c => c.source_citation).filter((x): x is string => !!x)));
    const cited_chunk_ids = chunks.map(c => c.id);
    const claim_strength_used = Array.from(new Set(chunks.map(c => c.claim_strength)));

    await sb.from("coach_response_log").insert({
      user_id: user_id ?? null,
      roadmap_node,
      coach_mode,
      user_input,
      coach_output: output,
      cited_chunk_ids,
      citations,
      claim_strength_used,
    });

    return new Response(JSON.stringify({
      coach_output: output,
      citations,
      mode: coach_mode,
      chunks: chunks.map(c => ({
        id: c.id, citation: c.source_citation, claim_strength: c.claim_strength, chunk_type: c.chunk_type,
      })),
    }), { headers: { ...CORS, "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 400, headers: { ...CORS, "Content-Type": "application/json" } });
  }
});