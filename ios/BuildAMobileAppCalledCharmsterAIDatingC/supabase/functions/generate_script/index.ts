// supabase/functions/generate_script/index.ts
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

async function embed(text: string): Promise<number[]> {
  const r = await fetch("https://api.openai.com/v1/embeddings", {
    method: "POST",
    headers: { "Authorization": `Bearer ${OPENAI_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ model: EMBED_MODEL, input: text }),
  });
  if (!r.ok) throw new Error(await r.text());
  return (await r.json()).data[0].embedding;
}

async function chat(system: string, user: string): Promise<string> {
  const r = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: { "Authorization": `Bearer ${OPENAI_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ model: CHAT_MODEL, temperature: 0.8,
      messages: [{ role: "system", content: system }, { role: "user", content: user }] }),
  });
  if (!r.ok) throw new Error(await r.text());
  return (await r.json()).choices[0].message.content as string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const { trend_source, roadmap_node } = await req.json();
    if (!trend_source || !roadmap_node) throw new Error("trend_source and roadmap_node required");

    const sb = createClient(SUPABASE_URL, SERVICE_KEY);
    const qv = await embed(trend_source);
    const { data: chunks, error } = await sb.rpc("match_knowledge_chunks", {
      query_embedding: qv as unknown as string,
      match_node: roadmap_node,
      match_mode: null,
      match_count: 8,
    });
    if (error) throw error;

    const peerReviewed = (chunks as any[]).filter(c => c.claim_strength === "peer_reviewed");
    if (peerReviewed.length === 0) {
      return new Response(JSON.stringify({
        error: "NO_PEER_REVIEWED_EVIDENCE",
        message: "Script generation aborted: no peer_reviewed chunk available for this node + trend.",
      }), { status: 422, headers: { ...CORS, "Content-Type": "application/json" } });
    }

    const ctx = (chunks as any[]).map((c, i) =>
      `[#${i + 1}] (${c.claim_strength}${c.source_citation ? `, ${c.source_citation}` : ""}) ${c.content}`
    ).join("\n");

    const system = `You are a short-form video script writer for a dating-skills coaching app. Fuse the supplied live trend with the retrieved evidence. Use authority language ("research shows…") ONLY when leaning on a peer_reviewed chunk. Output a 30-45s script with HOOK / POINT / EXAMPLE / CTA. Do not invent stats. Do not quote citations inline.

RETRIEVED EVIDENCE:
${ctx}`;
    const user = `Trend source: ${trend_source}\nRoadmap node: ${roadmap_node}`;
    const script_text = await chat(system, user);

    const attached_chunk_ids = (chunks as any[]).map(c => c.id);
    const { data: row, error: insErr } = await sb.from("script_approval_queue").insert({
      script_text,
      trend_source,
      attached_chunk_ids,
      has_peer_reviewed: true,
      status: "pending",
    }).select().single();
    if (insErr) throw insErr;

    return new Response(JSON.stringify({
      ok: true,
      script_id: row.id,
      script_text,
      citations: Array.from(new Set((chunks as any[]).map(c => c.source_citation).filter(Boolean))),
      status: "pending",
    }), { headers: { ...CORS, "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 400, headers: { ...CORS, "Content-Type": "application/json" } });
  }
});