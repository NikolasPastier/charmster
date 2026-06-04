// POST /generate_script
// Body: { trend_source, roadmap_node }
// Aborts if no peer_reviewed chunk is retrieved. Otherwise inserts into script_approval_queue.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const EMBED_MODEL = "text-embedding-3-small";
const CHAT_MODEL = "gpt-4o";

async function embed(text: string, key: string): Promise<number[]> {
  const r = await fetch("https://api.openai.com/v1/embeddings", {
    method: "POST",
    headers: { "Authorization": `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({ model: EMBED_MODEL, input: text }),
  });
  if (!r.ok) throw new Error(await r.text());
  return (await r.json()).data[0].embedding;
}

async function chat(messages: any[], key: string): Promise<string> {
  const r = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: { "Authorization": `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({ model: CHAT_MODEL, messages, temperature: 0.8, max_tokens: 500 }),
  });
  if (!r.ok) throw new Error(await r.text());
  return (await r.json()).choices[0].message.content;
}

Deno.serve(async (req) => {
  try {
    const { trend_source, roadmap_node } = await req.json();
    if (!trend_source || !roadmap_node) {
      return json({ error: "trend_source and roadmap_node required" }, 400);
    }
    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const openaiKey = Deno.env.get("OPENAI_API_KEY")!;

    const qEmb = await embed(trend_source, openaiKey);
    const { data: chunks, error } = await sb.rpc("match_knowledge_chunks", {
      query_embedding: qEmb,
      match_node: roadmap_node,
      match_mode: null,
      match_count: 8,
    });
    if (error) throw error;
    const retrieved = chunks ?? [];

    const peerReviewed = retrieved.filter((c: any) => c.claim_strength === "peer_reviewed");
    if (peerReviewed.length === 0) {
      return json({ error: "No peer_reviewed chunk available — script generation aborted (content-gating)." }, 422);
    }

    const block = retrieved.map((c: any, i: number) =>
      `[${i+1}] (${c.claim_strength}) ${c.source_citation ? "[" + c.source_citation + "]" : ""}: ${c.content}`
    ).join("\n");

    const system = `You are a short-form video scriptwriter for Charmster AI, a dating-coach app.
Fuse the trending insight with a peer_reviewed finding from the retrieved chunks. Paraphrase the science; cite the source plainly (e.g. "according to research by Gottman..."). Never invent stats. 90-120 words, 3 beats: hook, science, takeaway.

Retrieved chunks:
${block}`;

    const script_text = await chat([
      { role: "system", content: system },
      { role: "user", content: `Trend insight: ${trend_source}\nRoadmap node: ${roadmap_node}` },
    ], openaiKey);

    const attached = retrieved.map((c: any) => c.id);
    const { data: row, error: insErr } = await sb.from("script_approval_queue").insert({
      script_text,
      trend_source,
      attached_chunk_ids: attached,
      has_peer_reviewed: true,
      status: "pending",
    }).select().single();
    if (insErr) throw insErr;

    return json({
      ok: true, queue_id: row.id, script_text, status: "pending",
      attached_chunk_ids: attached,
      peer_reviewed_citations: peerReviewed.map((c: any) => c.source_citation),
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(body: any, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}