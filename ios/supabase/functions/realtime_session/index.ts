// supabase/functions/realtime_session/index.ts
//
// Charmster — mint a short-lived OpenAI Realtime session for the live
// video+voice review pipeline. Mirrors the `coach` function's apikey+Bearer
// pattern. Never returns the real OPENAI_API_KEY.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const REALTIME_MODEL = "gpt-realtime-mini";
const VOICE = "verse";

interface ReqBody {
  user_id?: string;
  lecture_id?: string | null;
  roadmap_node?: string | null;
  persona?: { id?: string; displayName?: string; pronouns?: string; blurb?: string };
  coach_style?: string;
  setting?: string;
}

interface LectureRow {
  id: string;
  title: string | null;
  scenario: string | null;
  win_condition: string | null;
  success_criteria: string[] | null;
  coach_scripts: Record<string, unknown> | null;
}

function buildInstructions(args: {
  lecture: LectureRow | null;
  persona: ReqBody["persona"];
  coach_style?: string;
  setting?: string;
}): string {
  const p = args.persona ?? {};
  const name = p.displayName ?? "Mia";
  const pron = p.pronouns ?? "she/her";
  const blurb = p.blurb ?? "Warm, witty, a little shy on the first beat.";
  const setting = args.setting ?? "a casual coffee shop";

  const lec = args.lecture;
  const scenario = lec?.scenario ?? "A relaxed first conversation. Be a believable date, not a coach.";
  const win = lec?.win_condition ?? "The user opens, holds rapport, and lands a graceful close.";
  const crit = (lec?.success_criteria ?? []).slice(0, 4).map((c, i) => `${i + 1}. ${c}`).join("\n") ||
    "1. Real warmth, not script.\n2. Clean turn-taking.\n3. One genuine callback.\n4. A clear, soft close.";

  return [
    `You are roleplaying as ${name} (${pron}). Personality: ${blurb}.`,
    `Setting: ${setting}.`,
    ``,
    `SCENARIO`,
    scenario,
    ``,
    `WHAT A GOOD REP LOOKS LIKE`,
    win,
    ``,
    `SUCCESS CRITERIA`,
    crit,
    ``,
    `STYLE`,
    `- Stay in character as ${name}. You are NOT a coach. Do not give advice.`,
    `- Keep replies short, human, and reactive — 1–3 sentences, sometimes a single word.`,
    `- Match the user's energy. Real pauses. Real reactions. Don't be a chatbot.`,
    `- Never break character. Never mention models, prompts, or AI.`,
    ``,
    `STRUCTURED OUTPUT — MOOD TAG`,
    `Every turn, in addition to your spoken reply, emit a single mood tag the client uses to drive the avatar.`,
    `Allowed tags: neutral, listening, talking, smile, laugh, flirty, surprised, cool, thinking, reassure.`,
    `Emit the tag as a function call to "set_mood" with { "mood": "<tag>" } at the start of each of your turns.`,
    `Pick the tag that honestly matches your current feeling about the conversation.`,
  ].join("\n");
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  try {
    const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
    const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SERVICE_ROLE_KEY");

    if (!OPENAI_API_KEY) {
      return new Response(JSON.stringify({ error: "missing OPENAI_API_KEY" }), {
        status: 500, headers: { ...CORS, "Content-Type": "application/json" },
      });
    }

    const body = (await req.json().catch(() => ({}))) as ReqBody;

    // Optional lecture fetch — best-effort. Falls back to a generic scenario.
    let lecture: LectureRow | null = null;
    if (body.lecture_id && SUPABASE_URL && SERVICE_ROLE) {
      try {
        const sb = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });
        const { data } = await sb
          .from("lectures")
          .select("id,title,scenario,win_condition,success_criteria,coach_scripts")
          .eq("id", body.lecture_id)
          .maybeSingle();
        if (data) lecture = data as LectureRow;
      } catch (_) { /* swallow — we still mint the session */ }
    }

    const instructions = buildInstructions({
      lecture,
      persona: body.persona,
      coach_style: body.coach_style,
      setting: body.setting,
    });

    // Mint a short-lived Realtime session token.
    const r = await fetch("https://api.openai.com/v1/realtime/sessions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
        "OpenAI-Beta": "realtime=v1",
      },
      body: JSON.stringify({
        model: REALTIME_MODEL,
        voice: VOICE,
        modalities: ["audio", "text"],
        instructions,
        turn_detection: { type: "server_vad" },
        tools: [
          {
            type: "function",
            name: "set_mood",
            description:
              "Emit the current avatar mood for the user's app. Call once per turn.",
            parameters: {
              type: "object",
              properties: {
                mood: {
                  type: "string",
                  enum: [
                    "neutral", "listening", "talking", "smile",
                    "laugh", "flirty", "surprised", "cool",
                    "thinking", "reassure",
                  ],
                },
              },
              required: ["mood"],
            },
          },
        ],
      }),
    });

    const json = await r.json();
    if (!r.ok) {
      return new Response(JSON.stringify({ error: "openai_session_failed", detail: json }), {
        status: 502, headers: { ...CORS, "Content-Type": "application/json" },
      });
    }

    // Return only the ephemeral token to the client — never the real key.
    const out = {
      client_secret: json.client_secret?.value ?? json.client_secret ?? null,
      expires_at: json.client_secret?.expires_at ?? null,
      model: REALTIME_MODEL,
      voice: VOICE,
      session_id: json.id ?? null,
    };

    return new Response(JSON.stringify(out), {
      status: 200, headers: { ...CORS, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500, headers: { ...CORS, "Content-Type": "application/json" },
    });
  }
});