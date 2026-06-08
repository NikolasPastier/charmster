import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    let body: any = {};
    try { body = await req.json(); } catch (_) {}
    const id: string | undefined = body?.id;

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const select = "id,track_id,lecture_number,title,scenario,teaching_content,principles,quiz,practice_opener,win_condition,coach_scripts,success_criteria";

    if (id) {
      const { data, error } = await supabase
        .from("lectures").select(select).eq("id", id).maybeSingle();
      if (error) throw error;
      return new Response(JSON.stringify({ lecture: data }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data, error } = await supabase
      .from("lectures").select(select).limit(500);
    if (error) throw error;
    return new Response(JSON.stringify({ lectures: data ?? [] }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e?.message ?? e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});