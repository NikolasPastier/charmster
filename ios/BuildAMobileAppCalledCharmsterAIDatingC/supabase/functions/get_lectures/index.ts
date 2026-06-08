// Public endpoint that returns lecture rows for the iOS client.
// No auth required (verify_jwt=false). Read-only.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const url = Deno.env.get("SUPABASE_URL")!;
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const sb = createClient(url, key);

  let id: string | null = null;
  try {
    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      id = body?.id ?? null;
    } else {
      id = new URL(req.url).searchParams.get("id");
    }
  } catch { /* noop */ }

  let q = sb
    .from("lectures")
    .select(
      "id,track_id,lecture_number,title,scenario,teaching_content,principles,quiz,practice_opener,win_condition,coach_scripts,success_criteria"
    )
    .order("track_id", { ascending: true })
    .order("lecture_number", { ascending: true });

  if (id) q = q.eq("id", id);

  const { data, error } = await q;
  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...cors, "content-type": "application/json" },
    });
  }
  return new Response(JSON.stringify({ lectures: data ?? [] }), {
    status: 200,
    headers: { ...cors, "content-type": "application/json" },
  });
});