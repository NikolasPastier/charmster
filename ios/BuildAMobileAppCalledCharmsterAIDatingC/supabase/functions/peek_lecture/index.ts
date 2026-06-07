import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  const { path } = await req.json().catch(() => ({ path: null }));
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );
  const target = path ?? "Lecture 1 2 The Similarity Magnet 8fc1654173da4974b89b7b3e21071767.md";
  const { data, error } = await supabase.storage.from("Lecture Library").download(target);
  if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  const text = await data.text();
  return new Response(JSON.stringify({ path: target, length: text.length, text }), {
    headers: { "Content-Type": "application/json" }
  });
});