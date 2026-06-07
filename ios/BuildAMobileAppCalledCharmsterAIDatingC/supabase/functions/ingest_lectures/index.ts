// supabase/functions/ingest_lectures/index.ts
// Reads every .md file from the "Lecture Library" storage bucket,
// parses Charmster's lecture markdown schema, and upserts into public.lectures.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const BUCKET = "Lecture Library";

interface QuizQ {
  prompt: string;
  options: string[];
  correctIndex: number;
}

interface Parsed {
  id: string;
  track_id: number;
  lecture_number: number;
  title: string;
  scenario: string | null;
  teaching_content: string | null;
  principles: string[];
  quiz: QuizQ[];
  practice_opener: string | null;
  win_condition: string | null;
  character_json: Record<string, unknown> | null;
  coach_scripts: Record<string, string>;
  scoring_weights: Record<string, number>;
  success_criteria: string | null;
  source_path: string;
  raw_markdown: string;
}

function stripMd(s: string): string {
  return s
    .replace(/\*\*/g, "")
    .replace(/\*/g, "")
    .replace(/`/g, "")
    .replace(/> /g, "")
    .replace(/^>\s*/gm, "")
    .replace(/\u00A0/g, " ")
    .trim();
}

function parseLecture(filename: string, md: string): Parsed | null {
  // Filename: "Lecture 3 1 Catching Bids for Connection f0e72e....md"
  const lectureMatch = filename.match(/^Lecture\s+(\d+)\s+(\d+)\s+(.+?)\s+[0-9a-f]{20,}\.md$/i);
  if (!lectureMatch) return null;
  const trackId = parseInt(lectureMatch[1], 10);
  const lectureNumber = parseInt(lectureMatch[2], 10);
  const id = `t${trackId}-l${lectureNumber}`;

  // Title from first H1
  const h1 = md.match(/^#\s+(.+)$/m);
  const titleRaw = h1 ? h1[1].trim() : lectureMatch[3].replace(/\s+/g, " ").trim();
  // Strip "Lecture 3.1 — " prefix
  const title = stripMd(titleRaw.replace(/^Lecture\s+\d+\.\d+\s*[—–-]\s*/i, ""));

  // Split into sections by "## " headings
  const sections: Record<string, string> = {};
  const lines = md.split("\n");
  let currentHeader = "_preamble";
  let buffer: string[] = [];
  for (const line of lines) {
    const h2 = line.match(/^##\s+(.+)$/);
    if (h2) {
      sections[currentHeader] = buffer.join("\n").trim();
      currentHeader = h2[1].trim().toLowerCase();
      buffer = [];
    } else {
      buffer.push(line);
    }
  }
  sections[currentHeader] = buffer.join("\n").trim();

  // Coach scripts: any section starting with "teaching script"
  const coach_scripts: Record<string, string> = {};
  for (const [header, body] of Object.entries(sections)) {
    if (header.startsWith("teaching script")) {
      // "teaching script — big brother" => "big brother"
      const coachName = header.replace(/^teaching script\s*[—–-]\s*/, "").trim() || "default";
      // Strip leading "*~85 seconds.*" italic line and blockquote markers
      const cleaned = stripMd(body.replace(/^\*~?[^*]+\*\s*/m, "").trim());
      coach_scripts[coachName] = cleaned;
    }
  }

  // Style notes section provides short voices for other coaches
  const styleNotes = sections["style notes — other 3"] ?? sections["style notes"];
  if (styleNotes) {
    const items = styleNotes.split(/\n-\s+/).map((s) => s.trim()).filter(Boolean);
    for (const item of items) {
      const m = item.match(/\*\*([^*]+):\*\*\s*\*?["“]?(.+?)["”]?\*?\s*$/s);
      if (m) {
        const name = m[1].replace(/[^\w\s]/g, "").trim().toLowerCase();
        coach_scripts[name] = stripMd(m[2]);
      }
    }
  }

  // Core takeaway → first principle
  const principles: string[] = [];
  const coreTakeaway = sections["core takeaway"];
  if (coreTakeaway) {
    principles.push(stripMd(coreTakeaway));
  }

  // Practice scenario block (parse fields: Setting / Context / Goal / Avatar briefing)
  const practiceBlock = sections["practice scenario"] ?? "";
  function fieldFrom(block: string, name: string): string | null {
    const re = new RegExp(`\\*\\*${name}:?\\*\\*\\s*([\\s\\S]+?)(?:\\n\\n|\\n\\*\\*|$)`, "i");
    const m = block.match(re);
    return m ? stripMd(m[1]).trim() : null;
  }
  const setting = fieldFrom(practiceBlock, "Setting");
  const context = fieldFrom(practiceBlock, "Context");
  const goal = fieldFrom(practiceBlock, "Goal");
  const avatarBrief = fieldFrom(practiceBlock, "Avatar briefing") ?? fieldFrom(practiceBlock, "System briefing");
  const scenario = [setting, context].filter(Boolean).join(" ") || null;
  const practice_opener = goal || null;
  const win_condition = avatarBrief;

  const character_json = avatarBrief ? { briefing: avatarBrief } : null;

  // Scoring profile table → weights
  const scoring_weights: Record<string, number> = {};
  const scoringBlock = sections["scoring profile"] ?? "";
  const rowRe = /\|\s*([^|]+?)\s*\|\s*(\d+)%\s*\|/g;
  let rowMatch: RegExpExecArray | null;
  while ((rowMatch = rowRe.exec(scoringBlock)) !== null) {
    const dim = stripMd(rowMatch[1]).toLowerCase();
    if (dim.includes("dimension")) continue;
    scoring_weights[dim] = parseInt(rowMatch[2], 10);
  }

  // Good vs bad → extra principles
  const goodBad = sections["good vs. bad"] ?? sections["good vs bad"];
  if (goodBad) {
    const goodM = goodBad.match(/✅\s*Good[^:]*:\s*\*?\*?(.+?)(?:\n\n|\*\*❌|$)/s);
    const badM = goodBad.match(/❌\s*Bad[^:]*:\s*\*?\*?(.+?)(?:\n\n|$)/s);
    if (goodM) principles.push("Good: " + stripMd(goodM[1]).slice(0, 220));
    if (badM) principles.push("Avoid: " + stripMd(badM[1]).slice(0, 220));
  }

  // Quiz
  const quiz: QuizQ[] = [];
  const quizBlock = sections["quiz"] ?? "";
  const qRe = /\*\*Q(\d+):\*\*\s*(.+?)\n([\s\S]+?)(?=\*\*Q\d+:|\n##|$)/g;
  let qm: RegExpExecArray | null;
  while ((qm = qRe.exec(quizBlock)) !== null) {
    const prompt = stripMd(qm[2]).trim();
    const body = qm[3];
    // Options separated by "·" or by "- A)" lines
    const options: string[] = [];
    let correctIndex = -1;
    // Try inline "- A) ... · B) ... · C) ..." format
    const inline = body.replace(/^\s*-\s*/, "").split(/·/);
    if (inline.length >= 2) {
      for (let i = 0; i < inline.length; i++) {
        let opt = inline[i].trim();
        const correct = /✅/.test(opt);
        opt = opt.replace(/✅/g, "").trim();
        opt = opt.replace(/^[A-D]\)\s*/, "").trim();
        opt = stripMd(opt);
        if (opt) {
          options.push(opt);
          if (correct) correctIndex = options.length - 1;
        }
      }
    }
    if (options.length >= 2 && correctIndex >= 0) {
      quiz.push({ prompt, options, correctIndex });
    }
  }

  // Success criteria
  const success_criteria = sections["success criteria"]
    ? stripMd(sections["success criteria"].replace(/^-\s*/gm, "")).replace(/\s+/g, " ").trim()
    : null;

  // Teaching content = concatenated coach scripts (prefer "big brother" first, then others)
  const preferredOrder = ["big brother", "the wingman", "wingman", "the scientist", "scientist"];
  const orderedKeys = [
    ...preferredOrder.filter((k) => coach_scripts[k]),
    ...Object.keys(coach_scripts).filter((k) => !preferredOrder.includes(k)),
  ];
  const teaching_content = orderedKeys.length
    ? orderedKeys.map((k) => coach_scripts[k]).join("\n\n")
    : null;

  return {
    id,
    track_id: trackId,
    lecture_number: lectureNumber,
    title,
    scenario,
    teaching_content,
    principles,
    quiz,
    practice_opener,
    win_condition,
    character_json,
    coach_scripts,
    scoring_weights,
    success_criteria,
    source_path: filename,
    raw_markdown: md,
  };
}

Deno.serve(async (req) => {
  const cors = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  };
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(url, serviceKey);

    // List all files in the bucket
    const { data: files, error: listErr } = await supabase.storage.from(BUCKET).list("", {
      limit: 500,
      sortBy: { column: "name", order: "asc" },
    });
    if (listErr) throw listErr;

    const results = {
      total: files?.length ?? 0,
      parsed: 0,
      skipped: 0,
      upserted: 0,
      errors: [] as Array<{ file: string; error: string }>,
      ids: [] as string[],
    };

    const batch: Parsed[] = [];
    for (const file of files ?? []) {
      if (!file.name.endsWith(".md")) {
        results.skipped++;
        continue;
      }
      if (!/^Lecture\s+\d+\s+\d+/i.test(file.name)) {
        // Skip Assessment, Track overview, master index
        results.skipped++;
        continue;
      }
      const { data: blob, error: dlErr } = await supabase.storage.from(BUCKET).download(file.name);
      if (dlErr || !blob) {
        results.errors.push({ file: file.name, error: dlErr?.message ?? "download failed" });
        continue;
      }
      const text = await blob.text();
      const parsed = parseLecture(file.name, text);
      if (!parsed) {
        results.errors.push({ file: file.name, error: "parse failed (filename pattern)" });
        continue;
      }
      results.parsed++;
      results.ids.push(parsed.id);
      batch.push(parsed);
    }

    // Upsert in chunks of 25
    for (let i = 0; i < batch.length; i += 25) {
      const chunk = batch.slice(i, i + 25).map((p) => ({
        ...p,
        updated_at: new Date().toISOString(),
      }));
      const { error: upErr } = await supabase.from("lectures").upsert(chunk, { onConflict: "id" });
      if (upErr) {
        results.errors.push({ file: `batch ${i}`, error: upErr.message });
      } else {
        results.upserted += chunk.length;
      }
    }

    return new Response(JSON.stringify(results, null, 2), {
      headers: { ...cors, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e?.message ?? e) }), {
      status: 500,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});