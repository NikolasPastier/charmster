// supabase/functions/ingest_lectures/index.ts
// Reads every markdown file in the "Lecture Library" storage bucket,
// parses the structured Charmster lecture schema, and upserts rows into public.lectures.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const BUCKET = "Lecture Library";

interface Parsed {
  id: string;
  track_id: number;
  lecture_number: number;
  title: string;
  scenario: string | null;
  teaching_content: string | null;
  principles: any;
  quiz: any;
  practice_opener: string | null;
  win_condition: string | null;
  character_json: any;
  coach_scripts: any;
  scoring_weights: any;
  success_criteria: string | null;
  source_path: string;
  raw_markdown: string;
}

function parseIdFromName(name: string): { track: number; lecture: number } | null {
  // Matches "Lecture 1 2 ..." or "Assessment 0 1 ..."
  const m = name.match(/(?:Lecture|Assessment)\s+(\d+)\s+(\d+)\s+/i);
  if (!m) return null;
  return { track: parseInt(m[1], 10), lecture: parseInt(m[2], 10) };
}

function extractTitle(md: string, fallback: string): string {
  const m = md.match(/^#\s+(?:Lecture|Assessment)\s+[\d.]+\s*[—\-–]\s*(.+)$/m);
  return m ? m[1].trim() : fallback;
}

function sectionBetween(md: string, startRe: RegExp, endRe: RegExp): string | null {
  const start = md.match(startRe);
  if (!start) return null;
  const after = md.slice(start.index! + start[0].length);
  const end = after.match(endRe);
  return (end ? after.slice(0, end.index!) : after).trim();
}

function extractCoachScripts(md: string): Record<string, string> {
  const out: Record<string, string> = {};
  const re = /##\s+Teaching script\s*[—\-–]\s*([^\n]+)\n([\s\S]*?)(?=\n##\s|\n---|$)/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(md)) !== null) {
    const name = m[1].trim();
    // Strip blockquote markers and italic timing line
    const body = m[2]
      .replace(/^\s*\*~[^*]+\*\s*$/gm, "")
      .replace(/^\s*>\s?/gm, "")
      .trim();
    if (body) out[name] = body;
  }
  // Style notes bullets
  const styleBlock = sectionBetween(md, /##\s+Style notes[^\n]*\n/, /\n##\s|\n---/);
  if (styleBlock) {
    const bulletRe = /[-*]\s+\*\*([^:*]+):\*\*\s*\*?"?([^*\n"]+)/g;
    let bm: RegExpExecArray | null;
    while ((bm = bulletRe.exec(styleBlock)) !== null) {
      out[bm[1].trim()] = bm[2].trim();
    }
  }
  return out;
}

function extractScenario(md: string): {
  scenario: string | null;
  opener: string | null;
  briefing: string | null;
} {
  const block = sectionBetween(md, /##\s+Practice scenario\s*\n/, /\n##\s|\n---/);
  if (!block) return { scenario: null, opener: null, briefing: null };
  const setting = block.match(/\*\*Setting:\*\*\s*([^\n]+)/i)?.[1]?.trim() ?? null;
  const context = block.match(/\*\*Context:\*\*\s*([^\n]+)/i)?.[1]?.trim() ?? null;
  const goal = block.match(/\*\*Goal:\*\*\s*([^\n]+)/i)?.[1]?.trim() ?? null;
  const briefing = block.match(/\*\*Avatar briefing:\*\*\s*([\s\S]+?)(?:\n\n|$)/i)?.[1]?.trim() ?? null;
  const parts = [setting, context, goal].filter(Boolean);
  return {
    scenario: parts.length ? parts.join(" \u00b7 ") : block,
    opener: goal,
    briefing,
  };
}

function extractScoringWeights(md: string): Record<string, number> | null {
  const block = sectionBetween(md, /##\s+Scoring profile\s*\n/, /\n##\s|\n---/);
  if (!block) return null;
  const out: Record<string, number> = {};
  const rowRe = /\|\s*([^|]+?)\s*\|\s*(\d+)\s*%\s*\|/g;
  let m: RegExpExecArray | null;
  while ((m = rowRe.exec(block)) !== null) {
    const key = m[1].trim();
    if (/dimension/i.test(key)) continue;
    out[key] = parseInt(m[2], 10);
  }
  return Object.keys(out).length ? out : null;
}

function extractQuiz(md: string): any[] {
  const block = sectionBetween(md, /##\s+Quiz\s*\n/, /\n##\s|\n---/);
  if (!block) return [];
  const questions: any[] = [];
  const qRe = /\*\*Q\d+:\*\*\s*([^\n]+)\n([\s\S]*?)(?=\n\*\*Q\d+:|\n##|\n---|$)/g;
  let m: RegExpExecArray | null;
  while ((m = qRe.exec(block)) !== null) {
    const prompt = m[1].trim();
    const optsRaw = m[2];
    // Options split by · or newlines starting with - A)
    const opts: { text: string; correct: boolean }[] = [];
    const splitRe = /(?:^|\n|·)\s*[-*]?\s*([A-E])\)\s*([^·\n]+)/g;
    let om: RegExpExecArray | null;
    while ((om = splitRe.exec(optsRaw)) !== null) {
      let text = om[2].trim();
      const correct = /✅/.test(text);
      text = text.replace(/✅/g, "").trim();
      opts.push({ text, correct });
    }
    if (prompt && opts.length) {
      questions.push({
        prompt,
        options: opts.map(o => o.text),
        correctIndex: opts.findIndex(o => o.correct),
      });
    }
  }
  return questions;
}

function extractCoreTakeaway(md: string): string | null {
  const block = sectionBetween(md, /##\s+Core takeaway\s*\n/, /\n##\s|\n---/);
  if (!block) return null;
  return block.replace(/^>\s?/gm, "").replace(/\*\*/g, "").trim();
}

function extractSuccessCriteria(md: string): string | null {
  const block = sectionBetween(md, /##\s+Success criteria\s*\n/, /\n##\s|\n---|$/);
  return block?.trim() ?? null;
}

function extractPrinciples(md: string, takeaway: string | null): string[] {
  const out: string[] = [];
  if (takeaway) out.push(takeaway);
  const gv = sectionBetween(md, /##\s+Good vs\.?\s+bad\s*\n/i, /\n##\s|\n---/);
  if (gv) {
    const good = gv.match(/✅\s*\*?\*?Good:?\*?\*?\s*([^\n]+)/i)?.[1]?.trim();
    const bad = gv.match(/❌\s*\*?\*?Bad:?\*?\*?\s*([^\n]+)/i)?.[1]?.trim();
    if (good) out.push("Do: " + good);
    if (bad) out.push("Avoid: " + bad);
  }
  return out;
}

function parseLecture(name: string, md: string): Parsed | null {
  const ids = parseIdFromName(name);
  if (!ids) return null;
  const id = `t${ids.track}-l${ids.lecture}`;
  const title = extractTitle(md, name.replace(/\.md$/i, ""));
  const coach_scripts = extractCoachScripts(md);
  const { scenario, opener, briefing } = extractScenario(md);
  const scoring_weights = extractScoringWeights(md);
  const quiz = extractQuiz(md);
  const takeaway = extractCoreTakeaway(md);
  const principles = extractPrinciples(md, takeaway);
  const success = extractSuccessCriteria(md);

  // Build teaching content: prefer Wingman / Big Brother / Scientist scripts joined
  const teaching = Object.entries(coach_scripts)
    .map(([k, v]) => `**${k}**\n\n${v}`)
    .join("\n\n");

  // Character JSON from briefing
  const character_json = briefing
    ? { briefing, name: null, vibe: null }
    : null;

  return {
    id,
    track_id: ids.track,
    lecture_number: ids.lecture,
    title,
    scenario,
    teaching_content: teaching || takeaway,
    principles,
    quiz,
    practice_opener: opener,
    win_condition: success,
    character_json,
    coach_scripts,
    scoring_weights,
    success_criteria: success,
    source_path: name,
    raw_markdown: md,
  };
}

Deno.serve(async (req) => {
  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // List all files in bucket (paginate)
    const files: { name: string }[] = [];
    let offset = 0;
    while (true) {
      const { data, error } = await supabase.storage
        .from(BUCKET)
        .list("", { limit: 100, offset, sortBy: { column: "name", order: "asc" } });
      if (error) throw error;
      if (!data || data.length === 0) break;
      files.push(...data.filter(f => f.name.toLowerCase().endsWith(".md")));
      if (data.length < 100) break;
      offset += data.length;
    }

    const results: { id?: string; name: string; ok: boolean; reason?: string }[] = [];
    const rows: Parsed[] = [];

    for (const f of files) {
      const { data: blob, error: dlErr } = await supabase.storage
        .from(BUCKET).download(f.name);
      if (dlErr || !blob) {
        results.push({ name: f.name, ok: false, reason: dlErr?.message ?? "download failed" });
        continue;
      }
      const md = await blob.text();
      const parsed = parseLecture(f.name, md);
      if (!parsed) {
        results.push({ name: f.name, ok: false, reason: "could not parse track/lecture id" });
        continue;
      }
      rows.push(parsed);
      results.push({ id: parsed.id, name: f.name, ok: true });
    }

    // Upsert in batches
    let upserted = 0;
    for (let i = 0; i < rows.length; i += 50) {
      const chunk = rows.slice(i, i + 50).map(r => ({ ...r, updated_at: new Date().toISOString() }));
      const { error } = await supabase.from("lectures").upsert(chunk, { onConflict: "id" });
      if (error) throw error;
      upserted += chunk.length;
    }

    return new Response(JSON.stringify({
      bucket: BUCKET,
      files_seen: files.length,
      upserted,
      skipped: results.filter(r => !r.ok),
    }, null, 2), { headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e?.message ?? e) }), {
      status: 500, headers: { "content-type": "application/json" },
    });
  }
});