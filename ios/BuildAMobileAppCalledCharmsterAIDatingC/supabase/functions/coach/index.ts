// POST /coach
// Body: { user_id?, roadmap_node, user_input, coach_mode? }
// Returns: { coach_output, citations, mode, claim_strength_used }
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const DEFAULT_MODE = "wingman";
const CHAT_MODEL = "gpt-4o";
const EMBED_MODEL = "text-embedding-3-small";

const PERSONAS: Record<string, string> = {
  hype_man: "You are the user's HYPE MAN coach. High-energy, affirming, momentum-focused. Celebrate effort and end with ONE tightening tip. Keep it under 120 words.",
  wingman: "You are the user's WINGMAN coach. Balanced and warm; explain the *why* and give ONE concrete next move. Keep it under 150 words.",
  hard_truth: "You are the user's HARD TRUTH coach. Blunt, no sugar-coating, name the mistake directly, still actionable, never cruel. Keep it under 130 words.",
};

async function embed(text: string, key: string): Promise<number[]> {
  const r = await fetch("https://api.openai.com/v1/embeddings", {
    method: "POST",
    headers: { "Authorization": `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({ model: EMBED_MODEL, input: text }),
  });
  if (!r.ok) throw new Error(`embed: ${await r.text()}`);
  return (await r.json()).data[0].embedding;
}

async function chat(messages: any[], key: string): Promise<string> {
  const r = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: { "Authorization": `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({ model: CHAT_MODEL, messages, temperature: 0.7, max_tokens: 400 }),
  });
  if (!r.ok) throw new Error(`chat: ${await r.text()}`);
  return (await r.json()).choices[0].message.content;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders() });
  try {
    const { user_id, roadmap_node, user_input, coach_mode } = await req.json();
    if (!roadmap_node || !user_input) {
      return json({ error: "roadmap_node and user_input required" }, 400);
    }

    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const openaiKey = Deno.env.get("OPENAI_API_KEY")!;

    // Resolve coach_mode
    let mode = coach_mode;
    if (!mode && user_id) {
      const { data } = await sb.from("profiles").select("preferred_coach_mode").eq("id", user_id).maybeSingle();
      mode = data?.preferred_coach_mode;
    }
    mode = mode || DEFAULT_MODE;
    if (!(mode in PERSONAS)) mode = DEFAULT_MODE;

    // Retrieve
    const qEmb = await embed(user_input, openaiKey);
    const { data: chunks, error: rpcErr } = await sb.rpc("match_knowledge_chunks", {
      query_embedding: qEmb,
      match_node: roadmap_node,
      match_mode: mode,
      match_count: 6,
    });
    if (rpcErr) throw rpcErr;
    const retrieved = chunks ?? [];

    const hasPeerReviewed = retrieved.some((c: any) => c.claim_strength === "peer_reviewed");
    const claimRule = hasPeerReviewed
      ? "Some retrieved chunks are peer_reviewed. Authority language ('research shows', 'studies find') is allowed ONLY when grounding a peer_reviewed chunk; cite the source plainly."
      : "NO peer_reviewed chunks were retrieved. Do NOT use 'research shows', 'studies say', or any authority language. Use softer framing: 'a common coaching idea is…', 'in my experience…'.";

    const chunkBlock = retrieved.map((c: any, i: number) =>
      `[${i+1}] (${c.claim_strength}, ${c.chunk_type}) ${c.source_citation ? "[" + c.source_citation + "]" : ""}\n${c.content}`
    ).join("\n\n");

    const system = `${PERSONAS[mode]}

You MUST ground your feedback in the retrieved knowledge chunks below. Never invent statistics or studies.

CLAIM GATING:
${claimRule}

Retrieved chunks:
${chunkBlock || "(none retrieved)"}`;

    const coach_output = await chat([
      { role: "system", content: system },
      { role: "user", content: user_input },
    ], openaiKey);

    const cited_chunk_ids = retrieved.map((c: any) => c.id);
    const citations = Array.from(new Set(retrieved.map((c: any) => c.source_citation).filter(Boolean)));
    const claim_strength_used = Array.from(new Set(retrieved.map((c: any) => c.claim_strength)));

    if (user_id) {
      await sb.from("coach_response_log").insert({
        user_id, roadmap_node, coach_mode: mode,
        user_input, coach_output,
        cited_chunk_ids, citations, claim_strength_used,
      });
    }

    return json({ coach_output, citations, mode, claim_strength_used });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
}
function json(body: any, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json", ...corsHeaders() } });
}