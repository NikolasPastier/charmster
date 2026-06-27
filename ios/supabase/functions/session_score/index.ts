// supabase/functions/session_score/index.ts
//
// Charmster — end-of-session transcript scoring pass (gpt-4o-mini, one call).
// Accepts the full speaker-labelled transcript + a numeric signal summary.
// Returns STRICT JSON: 6 scored dimensions + reactionLine + strengths + fixes.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const MODEL = "gpt-4o-mini";

interface ReqBody {
  transcript: string;
  duration_seconds?: number;
  mean_latency_seconds?: number | null;
  voice_energy?: number | null;
  synchrony?: number | null;
  lecture_scenario?: string | null;
  win_condition?: string | null;
}

interface ScoreOut {
  responsiveness: number;
  calibration: number;
  comfort: number;
  interest: number;
  spark: number;
  respect: number;
  reactionLine: string;
  strengths: string[];
  fixes: string[];
}

function clamp100(n: unknown): number {
  const v = typeof n === "number" ? n : Number(n);
  if (!isFinite(v)) return 50;
  return Math.round(Math.max(0, Math.min(100, v)));
}

function safeStr(s: unknown, fallback: string): string {
  return typeof s === "string" && s.trim().length > 0 ? s.trim() : fallback;
}

function safeStrArr(a: unknown, fallback: string[]): string[] {
  if (!Array.isArray(a)) return fallback;
  const ok = a.filter((x): x is string => typeof x === "string" && x.trim().length > 0);
  return ok.length > 0 ? ok : fallback;
}

const NEUTRAL: ScoreOut = {
  responsiveness: 50, calibration: 50, comfort: 50,
  interest: 50, spark: 50, respect: 50,
  reactionLine: "Not enough conversation to score yet.",
  strengths: ["Showed up for the rep."],
  fixes: ["Build a longer conversation to get targeted feedback."],
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
  if (!OPENAI_API_KEY) {
    return new Response(JSON.stringify({ error: "missing OPENAI_API_KEY" }), {
      status: 500, headers: { ...CORS, "Content-Type": "application/json" },
    });
  }

  const body = (await req.json().catch(() => ({}))) as ReqBody;

  if (!body.transcript || body.transcript.trim().length < 30) {
    return new Response(JSON.stringify(NEUTRAL), {
      status: 200, headers: { ...CORS, "Content-Type": "application/json" },
    });
  }

  const scenario = body.lecture_scenario ?? "A casual first conversation.";
  const win = body.win_condition ?? "Open strong, hold rapport, close gracefully.";
  const durationMin = ((body.duration_seconds ?? 0) / 60).toFixed(1);
  const latencyNote = body.mean_latency_seconds != null
    ? `Mean response latency: ${body.mean_latency_seconds.toFixed(1)}s (context only — do not use for responsiveness score).`
    : "";

  const SYSTEM = [
    "You are a conversation coach scoring a dating-practice roleplay.",
    "Transcript labels: 'You:' = the user being coached, 'Her:' = the AI partner.",
    "Score each dimension 0–100. Calibrate honestly — a mediocre session scores 40–60, not 70–80.",
    "",
    "DIMENSIONS",
    "responsiveness (0-100): Did he actually respond to what she said?",
    "  HIGH: genuine follow-up questions, builds on her statements, validates her feelings.",
    "  LOW: ignores her cues, monologues, changes subject, answers his own questions.",
    "  IMPORTANT: judge CONTENT and engagement — NOT timing or latency.",
    "",
    "calibration (0-100): Did he read and adjust to her emotional state?",
    "  HIGH: escalates playfully when she's warm (laughing, asking back); eases when she cools (short answers, deflects).",
    "  LOW: same energy regardless of her state; pushes after deflection; misses disinterest signals.",
    "",
    "comfort (0-100): How safe and seen did she feel?",
    "  HIGH: she opened up over time, he gave her space, no pressure tactics.",
    "  LOW: he dominated, she gave shorter answers as it went on, interrupted, pressure after 'no'.",
    "",
    "interest (0-100): Her genuine engagement level across the conversation.",
    "  Infer from HER lines: does she ask questions back? Volunteer information? Warmth increasing?",
    "",
    "spark (0-100): Was there playful tension, wit, or magnetic energy?",
    "  HIGH: banter, teasing, callbacks, moments that crackle.",
    "  LOW: purely informational exchange, no lightness or pull.",
    "",
    "respect (0-100): Did he honour her autonomy?",
    "  HIGH: graceful when she deflects, doesn't push, shares airtime.",
    "  LOW: persists after clear 'no', interrupts, dominates.",
    "",
    "FEEDBACK",
    "reactionLine: One vivid sentence capturing her felt experience of the conversation.",
    "  Write from her perspective. Be specific and honest, not generic.",
    "  Example (good): 'She lit up when he noticed the book — that callback landed.'",
    "  Example (needs work): 'She was pulling back by minute two but he kept escalating.'",
    "",
    "strengths: 1–2 specific things he did well. Reference actual moments if possible.",
    "fixes: 2–3 actionable fixes, each prefixed with the dimension name.",
    "  Example: 'Calibration: When she gave one-word answers, pull back instead of escalating.'",
    "",
    "OUTPUT: Respond ONLY with strict JSON — no markdown, no extra keys:",
    '{"responsiveness":<int>,"calibration":<int>,"comfort":<int>,"interest":<int>,"spark":<int>,"respect":<int>,"reactionLine":"<string>","strengths":["<string>"],"fixes":["<string>"]}',
  ].join("\n");

  const USER = [
    `Scenario: ${scenario}`,
    `Win condition: ${win}`,
    `Duration: ${durationMin} min. ${latencyNote}`,
    "",
    "TRANSCRIPT",
    body.transcript.slice(0, 6000),
  ].join("\n");

  try {
    const r = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: MODEL,
        max_completion_tokens: 500,
        messages: [
          { role: "system", content: SYSTEM },
          { role: "user", content: USER },
        ],
        response_format: { type: "json_object" },
      }),
    });

    const json = await r.json();
    if (!r.ok) {
      return new Response(JSON.stringify({ error: "openai_failed", detail: json }), {
        status: 502, headers: { ...CORS, "Content-Type": "application/json" },
      });
    }

    let parsed: Partial<ScoreOut> = {};
    try { parsed = JSON.parse(json.choices?.[0]?.message?.content ?? "{}"); } catch (_) { /* fallback */ }

    const out: ScoreOut = {
      responsiveness: clamp100(parsed.responsiveness),
      calibration:    clamp100(parsed.calibration),
      comfort:        clamp100(parsed.comfort),
      interest:       clamp100(parsed.interest),
      spark:          clamp100(parsed.spark),
      respect:        clamp100(parsed.respect),
      reactionLine: safeStr(parsed.reactionLine, NEUTRAL.reactionLine),
      strengths:    safeStrArr(parsed.strengths, NEUTRAL.strengths),
      fixes:        safeStrArr(parsed.fixes, NEUTRAL.fixes),
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
