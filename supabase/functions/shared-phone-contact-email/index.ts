import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const emailPattern = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

function respond(status: number, code: string): Response {
  return new Response(JSON.stringify({ code }), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }
  if (request.method !== "POST") return respond(405, "method_not_allowed");

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const twilioSid = Deno.env.get("TWILIO_API_KEY_SID");
  const twilioSecret = Deno.env.get("TWILIO_API_KEY_SECRET");
  if (!url || !anonKey || !serviceKey || !twilioSid || !twilioSecret) {
    return respond(503, "service_unavailable");
  }
  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return respond(401, "unauthorized");
  }

  try {
    const raw = await request.text();
    if (new TextEncoder().encode(raw).byteLength > 1024) {
      return respond(413, "request_too_large");
    }
    const body = JSON.parse(raw);
    const action = body?.action;
    const code = String(body?.code ?? "").trim();
    if ((action !== "send" && action !== "check") ||
        (action === "check" && !/^\d{8}$/.test(code))) {
      return respond(400, "invalid_request");
    }

    const userClient = createClient(url, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: { user }, error: userError } =
      await userClient.auth.getUser();
    if (userError || !user) return respond(401, "unauthorized");

    const contactEmail = String(
      user.app_metadata?.maplov_contact_email ?? "",
    ).trim().toLowerCase();
    if (!user.email?.startsWith("shared-") ||
        !user.email.endsWith("@accounts.maplov.ca") ||
        user.app_metadata?.maplov_shared_test_phone_verified !== true ||
        user.app_metadata?.maplov_contact_email_verified === true ||
        !emailPattern.test(contactEmail)) {
      return respond(403, "email_verification_unavailable");
    }

    const admin = createClient(url, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    if (action === "send") {
      const digits = new Uint32Array(1);
      crypto.getRandomValues(digits);
      const oneTimeCode = String(digits[0] % 100000000).padStart(8, "0");
      const { data: allowed, error: claimError } = await admin.rpc(
        "claim_shared_phone_contact_email_code",
        { owner_user: user.id, supplied_code: oneTimeCode },
      );
      if (claimError) {
        console.error("Contact email code claim failed", { code: claimError.code });
        return respond(503, "service_unavailable");
      }
      if (allowed !== true) return respond(429, "email_rate_limited");

      const response = await fetch("https://comms.twilio.com/v1/Emails", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Basic ${btoa(`${twilioSid}:${twilioSecret}`)}`,
        },
        body: JSON.stringify({
          from: { address: "noreply@maplov.ca", name: "MapLov" },
          to: [{ address: contactEmail }],
          content: {
            subject: "MapLov — verify your email / vérifiez votre courriel",
            text:
              `MapLov verification code: ${oneTimeCode}\nCode de vérification MapLov : ${oneTimeCode}\nThis code expires in one hour. / Ce code expire dans une heure.`,
            html:
              `<p>MapLov — verify your email / vérifiez votre courriel</p><p style="font-size:28px;font-weight:bold">${oneTimeCode}</p><p>This code expires in one hour. / Ce code expire dans une heure.</p>`,
          },
        }),
        signal: AbortSignal.timeout(8000),
      });
      if (!response.ok) {
        console.error("Contact email provider failed", {
          status: response.status,
        });
        return respond(502, "email_provider_unavailable");
      }
      return respond(200, "code_sent");
    }

    const { data: valid, error: checkError } = await admin.rpc(
      "check_shared_phone_contact_email_code",
      { owner_user: user.id, supplied_code: code },
    );
    if (checkError) {
      console.error("Contact email code check failed", { code: checkError.code });
      return respond(503, "service_unavailable");
    }
    if (valid !== true) return respond(400, "invalid_code");

    const { error: updateError } = await admin.auth.admin.updateUserById(
      user.id,
      {
        email: contactEmail,
        email_confirm: true,
        app_metadata: {
          ...user.app_metadata,
          maplov_contact_email_verified: true,
          maplov_contact_email_verified_at: new Date().toISOString(),
        },
      },
    );
    if (updateError) {
      console.error("Contact email confirmation failed", {
        code: updateError.code,
        status: updateError.status,
      });
      return respond(
        updateError.status === 422 ? 409 : 503,
        updateError.status === 422 ? "email_already_in_use" : "service_unavailable",
      );
    }
    return respond(200, "email_verified");
  } catch (error) {
    console.error("Shared phone contact email failed", {
      category: error instanceof SyntaxError ? "invalid_json" : "internal_error",
    });
    return respond(error instanceof SyntaxError ? 400 : 503,
      error instanceof SyntaxError ? "invalid_request" : "service_unavailable");
  }
});
