import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const MAX_BODY_BYTES = 2048;
const TWILIO_TIMEOUT_MS = 8000;

function reply(
  status: number,
  code: string,
  data: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify({ code, ...data }), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function verifyWithTwilio(
  action: "send" | "check",
  phone: string,
  code: string,
  serviceSid: string,
  credentials: string,
): Promise<Response> {
  const endpoint = action === "send" ? "Verifications" : "VerificationCheck";
  const params = new URLSearchParams({ To: phone });
  if (action === "send") {
    params.set("Channel", "sms");
  } else {
    params.set("Code", code);
  }
  const response = await fetch(
    `https://verify.twilio.com/v2/Services/${serviceSid}/${endpoint}`,
    {
      method: "POST",
      headers: {
        "Authorization": `Basic ${credentials}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: params.toString(),
      signal: AbortSignal.timeout(TWILIO_TIMEOUT_MS),
    },
  );
  if (!response.ok) {
    let twilioCode: number | string | undefined;
    try {
      const error = await response.json();
      if (typeof error?.code === "number" ||
          typeof error?.code === "string") {
        twilioCode = error.code;
      }
    } catch {
      // Do not expose the provider's raw response or the submitted code.
    }
    console.error("Registration SMS provider failed", {
      action,
      httpStatus: response.status,
      twilioCode,
    });
    if (action === "check" &&
        (response.status === 400 || response.status === 404)) {
      return reply(400, "invalid_code");
    }
    if (response.status === 429) return reply(429, "sms_rate_limited");
    return reply(502, "sms_provider_unavailable");
  }
  const result = await response.json();
  if (action === "send") {
    return result.status === "pending"
      ? reply(200, "code_sent")
      : reply(502, "sms_provider_unavailable");
  }
  return result.status === "approved"
    ? reply(200, "code_approved")
    : reply(400, "invalid_code");
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") return reply(405, "method_not_allowed");

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const twilioKeySid = Deno.env.get("TWILIO_VERIFY_API_KEY_SID");
  const twilioKeySecret = Deno.env.get("TWILIO_VERIFY_API_KEY_SECRET");
  const verifySid = Deno.env.get("TWILIO_VERIFY_SERVICE_SID");
  if (!url || !anonKey || !serviceKey || !twilioKeySid ||
      !twilioKeySecret || !verifySid) {
    console.error("Registration SMS fallback is not configured");
    return reply(503, "service_unavailable");
  }

  try {
    const raw = await request.text();
    if (new TextEncoder().encode(raw).byteLength > MAX_BODY_BYTES) {
      return reply(413, "request_too_large");
    }
    const body = JSON.parse(raw);
    if (body === null || typeof body !== "object") {
      return reply(400, "invalid_request");
    }
    const action = body.action;
    const email = String(body.email ?? "").trim().toLowerCase();
    const password = String(body.password ?? "");
    const phone = String(body.phone ?? "").trim();
    const code = String(body.code ?? "").trim();
    if ((action !== "send" && action !== "check") ||
        !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) ||
        password.length > 1024 || (password.length > 0 && password.length < 8) ||
        !/^\+[1-9]\d{7,14}$/.test(phone) ||
        (action === "check" && !/^\d{4,10}$/.test(code))) {
      return reply(400, "invalid_request");
    }

    const testDeadline = Date.parse(
      Deno.env.get("DUPLICATE_ACCOUNT_BYPASS_UNTIL") ?? "",
    );
    const sharedPhoneWindow = phone ===
        Deno.env.get("MAPLOV_SHARED_TEST_PHONE") &&
      Number.isFinite(testDeadline) && Date.now() < testDeadline;
    // Only the temporary, explicitly allowlisted phone may use SMS as the
    // initial proof. Every other registration still requires its password.
    if (!password && !sharedPhoneWindow) return reply(403, "registration_unavailable");
    if (password) {
      const authClient = createClient(url, anonKey, {
        auth: { persistSession: false, autoRefreshToken: false },
      });
      const { data: existingAuth, error: passwordError } =
        await authClient.auth.signInWithPassword({ email, password });
      if (passwordError?.code !== "email_not_confirmed") {
        const existingPhone = existingAuth?.user?.phone ??
          existingAuth?.user?.user_metadata?.phone_number;
        if (!passwordError && existingPhone === phone) {
          return reply(409, "phone_already_linked");
        }
        return reply(403, "registration_unavailable");
      }
    }

    const admin = createClient(url, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: userId, error: lookupError } = await admin.rpc(
      "find_pending_registration_for_sms",
      { email_value: email, phone_value: phone },
    );
    if (lookupError) {
      console.error("Registration SMS lookup failed", {
        code: lookupError.code,
      });
      return reply(503, "service_unavailable");
    }
    if (typeof userId !== "string") {
      return reply(403, "registration_unavailable");
    }

    const { data: phoneLinked, error: phoneLookupError } = await admin.rpc(
      "registration_sms_phone_linked_elsewhere",
      { owner_user: userId, phone_value: phone },
    );
    if (phoneLookupError) {
      console.error("Registration SMS phone lookup failed", {
        code: phoneLookupError.code,
      });
      return reply(503, "service_unavailable");
    }
    const sharedPhoneAllowed = phoneLinked === true &&
      sharedPhoneWindow;
    if (!password && !sharedPhoneAllowed) {
      return reply(403, "registration_unavailable");
    }
    if (phoneLinked === true && !sharedPhoneAllowed) {
      return reply(409, "phone_already_linked");
    }

    const credentials = btoa(`${twilioKeySid}:${twilioKeySecret}`);
    if (action === "send") {
      const { data: allowed, error: limitError } = await admin.rpc(
        "claim_registration_sms_fallback_send",
        { owner_user: userId, phone_value: phone },
      );
      if (limitError) {
        console.error("Registration SMS rate limit failed", {
          code: limitError.code,
        });
        return reply(503, "service_unavailable");
      }
      if (allowed !== true) return reply(429, "sms_rate_limited");
      return await verifyWithTwilio(
        "send", phone, "", verifySid, credentials,
      );
    }

    const verification = await verifyWithTwilio(
      "check", phone, code, verifySid, credentials,
    );
    if (verification.status !== 200) return verification;

    const { data: account, error: accountError } =
      await admin.auth.admin.getUserById(userId);
    if (accountError || !account.user || account.user.email_confirmed_at) {
      return reply(409, "registration_unavailable");
    }
    if (sharedPhoneAllowed) {
      const authEmail = `shared-${crypto.randomUUID()}@accounts.maplov.ca`;
      const { error: sharedUpdateError } =
        await admin.auth.admin.updateUserById(userId, {
          email: authEmail,
          email_confirm: true,
          app_metadata: {
            ...account.user.app_metadata,
            maplov_contact_email: email,
            maplov_contact_email_verified: false,
            maplov_shared_test_phone_verified: true,
            maplov_shared_test_phone: phone,
            maplov_sms_fallback_verified: true,
            maplov_sms_fallback_verified_at: new Date().toISOString(),
          },
        });
      if (sharedUpdateError) {
        console.error("Shared phone registration update failed", {
          code: sharedUpdateError.code,
          status: sharedUpdateError.status,
        });
        return reply(503, "service_unavailable");
      }
      // A bearer proof is issued only after Twilio approved the SMS code.
      // The alias is an internal Auth identity; the real contact email stays
      // explicitly unverified in app_metadata until its own code is checked.
      const { data: link, error: linkError } =
        await admin.auth.admin.generateLink({ type: "magiclink", email: authEmail });
      const tokenHash = link?.properties?.hashed_token;
      if (linkError || typeof tokenHash !== "string" || !tokenHash) {
        console.error("Shared phone session grant failed", {
          code: linkError?.code,
        });
        return reply(503, "service_unavailable");
      }
      return reply(200, "phone_verified_email_pending", {
        auth_email: authEmail,
        token_hash: tokenHash,
      });
    }
    const { error: updateError } = await admin.auth.admin.updateUserById(
      userId,
      {
        phone,
        phone_confirm: true,
        app_metadata: {
          ...account.user.app_metadata,
          maplov_sms_fallback_verified: true,
          maplov_sms_fallback_verified_at: new Date().toISOString(),
        },
      },
    );
    if (updateError) {
      console.error("Registration SMS account update failed", {
        code: updateError.code,
        status: updateError.status,
      });
      const { data: linkedAfterError } = await admin.rpc(
        "registration_sms_phone_linked_elsewhere",
        { owner_user: userId, phone_value: phone },
      );
      if (linkedAfterError === true) {
        return reply(409, "phone_already_linked");
      }
      return reply(503, "service_unavailable");
    }
    return reply(200, "phone_verified_email_pending");
  } catch (error) {
    console.error("Registration SMS fallback failed", {
      category: error instanceof SyntaxError ? "invalid_json" : "internal_error",
    });
    return reply(error instanceof SyntaxError ? 400 : 503,
      error instanceof SyntaxError ? "invalid_request" : "service_unavailable");
  }
});
