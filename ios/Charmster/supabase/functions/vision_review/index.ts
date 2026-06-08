// supabase/functions/vision_review/index.ts
//
// Charmster — score a single sampled camera frame for face/body presence.
// Stateless. The client samples ~1 frame every 2.5s, never streams video,
// and never stores raw frames server-side.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const MODEL = "gpt-4o-mini";

interface ReqBody {
  user_id?: string;
  session_id?: string;
  lecture_id?: string | null;
  // Base64-encoded JPEG (no data: prefix) — single sampled frame.
  frame_jpeg_base64: string;
  transcript_snippet?: string | null;
}

interface VisionScore {
  face: number;   // 0..100  smile + eye contact + presence
  body: number;   // 0..100  posture + openness + framing
  warmth: number; // 0..1    composite warmth signal
  presence: number; // 0..1
  notes?: string;
}

function clamp01(n: unknown): number {
  const v = typeof n === "number" ? n : Number(n);
  if (!isFinite(v)) return 0.5;
  return Math.max(0, Math.min(1, v));
}
function clamp100(n: unknown): number {
  const v = typeof n === "number" ? n : Number(n);
  if (!isFinite(v)) return 50;
  return Math.round(Math.max(0, Math.min(100, v)));
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  try {
    const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
    if (!OPENAI_API_KEY) {
      return new Response(JSON.stringify({ error: "missing OPENAI_API_KEY" }), {
        status: 500, headers: { ...CORS, "Content-Type": "application/json" },
      });
    }

    const body = (await req.json().catch(() => ({}))) as ReqBody;
    if (!body.frame_jpeg_base64) {
      return new Response(JSON.stringify({ error: "missing frame_jpeg_base64" }), {
        status: 400, headers: { ...CORS, "Content-Type": "application/json" },
      });
    }

    const dataUrl = `data:image/jpeg;base64,${body.frame_jpeg_base64}`;

    const prompt = [
      "You are a non-judgmental social-presence rater for a dating-confidence app.",
      "Look at this single sampled frame of the USER (front camera).",
      "Estimate three latent signals on 0..1 scales:",
      "- presence: how engaged + grounded the person looks (eye contact, head orientation, alertness).",
      "- warmth: how friendly + open the face reads (smile micro-signals, soft eyes, jaw tension).",
      "- power: how rooted + confident the body reads (shoulders, posture, framing — not aggression).",
      "Then output a face score (0..100) ≈ 60*presence + 40*warmth,",
      "and a body score (0..100) ≈ 60*power + 40*presence.",
      "Be kind but honest. Never describe the person physically. Reply ONLY as JSON:",
      `{"face": <int 0..100>, "body": <int 0..100>, "warmth": <0..1>, "presence": <0..1>, "notes": "<short>"}`,
      body.transcript_snippet ? `Recent user line (for context): ${body.transcript_snippet.slice(0, 240)}` : "",
    ].filter(Boolean).join("\n");

    const r = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: MODEL,
        max_completion_tokens: 220,
        messages: [
          {
            role: "user",
            content: [
              { type: "text", text: prompt },
              { type: "image_url", image_url: { url: dataUrl, detail: "low" } },
            ],
          },
        ],
        response_format: { type: "json_object" },
      }),
    });

    const json = await r.json();
    if (!r.ok) {
      return new Response(JSON.stringify({ error: "openai_vision_failed", detail: json }), {
        status: 502, headers: { ...CORS, "Content-Type": "application/json" },
      });
    }

    let parsed: Partial<VisionScore> = {};
    try {
      parsed = JSON.parse(json.choices?.[0]?.message?.content ?? "{}");
    } catch (_) { /* leave empty -> defaults */ }

    const out: VisionScore = {
      face: clamp100(parsed.face),
      body: clamp100(parsed.body),
      warmth: clamp01(parsed.warmth),
      presence: clamp01(parsed.presence),
      notes: typeof parsed.notes === "string" ? parsed.notes.slice(0, 200) : undefined,
    };

    // Best-effort logging — never blocks the response.
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
    const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SERVICE_ROLE_KEY");
    if (SUPABASE_URL && SERVICE_ROLE) {
      try {
        const sb = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });
        await sb.from("coach_response_log").insert({
          kind: "vision_review",
          user_id: body.user_id ?? null,
          session_id: body.session_id ?? null,
          lecture_id: body.lecture_id ?? null,
          payload: out,
        });
      } catch (_) { /* logging is non-critical */ }
    }

    return new Response(JSON.stringify(out), {
      status: 200, headers: { ...CORS, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { ...CORS, "Content-Type": "application/json" },
    });
  }
});