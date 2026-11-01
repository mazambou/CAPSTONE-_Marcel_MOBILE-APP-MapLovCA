import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function respond(status: number, body: Record<string, string>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }
  if (request.method !== "POST") return respond(405, { code: "method_not_allowed" });

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) {
    return respond(503, { code: "service_unavailable" });
  }
  try {
    const raw = await request.text();
    if (new TextEncoder().encode(raw).byteLength > 2048) {
      return respond(413, { code: "request_too_large" });
    }
    const body = JSON.parse(raw);
    const email = String(body?.email ?? "").trim().toLowerCase();
    const password = String(body?.password ?? "");
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) ||
        password.length < 8 || password.length > 1024) {
      return respond(400, { code: "invalid_request" });
    }

    const admin = createClient(url, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: alias, error: lookupError } = await admin.rpc(
      "find_pending_shared_phone_auth_email",
      { contact_email: email },
    );
    if (lookupError) {
      console.error("Shared phone alias lookup failed", { code: lookupError.code });
      return respond(503, { code: "service_unavailable" });
    }
    if (typeof alias !== "string") {
      return respond(403, { code: "invalid_login" });
    }
    const authClient = createClient(url, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { error: signInError } = await authClient.auth.signInWithPassword({
      email: alias,
      password,
    });
    if (signInError) return respond(403, { code: "invalid_login" });
    return respond(200, { code: "alias_ready", auth_email: alias });
  } catch (error) {
    console.error("Shared phone alias login failed", {
      category: error instanceof SyntaxError ? "invalid_json" : "internal_error",
    });
    return respond(error instanceof SyntaxError ? 400 : 503, {
      code: error instanceof SyntaxError ? "invalid_request" : "service_unavailable",
    });
  }
});
