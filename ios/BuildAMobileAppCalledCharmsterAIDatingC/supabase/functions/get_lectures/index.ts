// deno-lint-ignore-file no-explicit-any
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "*",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
  "Content-Type": "application/json",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE);
    const { data, error } = await supabase
      .from("lectures")
      .select(
        "id,track_id,lecture_number,title,scenario,teaching_content,principles,quiz,practice_opener,win_condition,coach_scripts,success_criteria"
      )
      .order("track_id", { ascending: true })
      .order("lecture_number", { ascending: true })
      .limit(500);
    if (error) throw error;
    return new Response(JSON.stringify({ lectures: data ?? [] }), { headers: cors });
  } catch (e: any) {
    return new Response(JSON.stringify({ error: String(e?.message ?? e) }), {
      status: 500,
      headers: cors,
    });
  }
});