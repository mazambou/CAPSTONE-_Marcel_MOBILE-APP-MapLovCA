import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const MAX_BODY_BYTES = 12000;
const PHONE = /^\+[1-9]\d{7,14}$/;
const EMAIL = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const CODE = /^\d{4,10}$/;

function respond(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

function testWindow() {
  const value = Deno.env.get("DUPLICATE_ACCOUNT_BYPASS_UNTIL") ?? "";
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.test(value)) {
    return { active: false, until: null };
  }
  const deadline = Date.parse(value);
  return {
    active: Number.isFinite(deadline) && Date.now() < deadline,
    until: Number.isFinite(deadline) ? value : null,
  };
}

function accountRows(value: unknown): Array<Record<string, unknown>> {
  return Array.isArray(value) ? value.filter((item) =>
    item !== null && typeof item === "object"
  ) : [];
}

async function twilioVerify(
  action: "send" | "check",
  phone: string,
  code: string,
  serviceSid: string,
  credentials: string,
): Promise<{ ok: boolean; status: number; error?: string }> {
  const endpoint = action === "send" ? "Verifications" : "VerificationCheck";
  const params = new URLSearchParams({ To: phone });
  if (action === "send") params.set("Channel", "sms");
  else params.set("Code", code);
  const response = await fetch(
    `https://verify.twilio.com/v2/Services/${serviceSid}/${endpoint}`,
    {
      method: "POST",
      headers: {
        Authorization: `Basic ${credentials}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: params.toString(),
      signal: AbortSignal.timeout(8000),
    },
  );
  if (!response.ok) {
    console.error("Test account SMS provider failed", {
      action,
      httpStatus: response.status,
    });
    if (action === "check" && [400, 404].includes(response.status)) {
      return { ok: false, status: 400, error: "invalid_code" };
    }
    if (response.status === 429) {
      return { ok: false, status: 429, error: "sms_rate_limited" };
    }
    return { ok: false, status: 502, error: "sms_provider_unavailable" };
  }
  const result = await response.json();
  return result?.status === (action === "send" ? "pending" : "approved")
    ? { ok: true, status: 200 }
    : { ok: false, status: action === "send" ? 502 : 400,
      error: action === "send" ? "sms_provider_unavailable" : "invalid_code" };
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (request.method !== "POST") return respond(405, { code: "method_not_allowed" });

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const verifySid = Deno.env.get("TWILIO_VERIFY_SERVICE_SID");
  const twilioSid = Deno.env.get("TWILIO_VERIFY_API_KEY_SID");
  const twilioSecret = Deno.env.get("TWILIO_VERIFY_API_KEY_SECRET");
  if (!url || !serviceKey || !verifySid || !twilioSid || !twilioSecret) {
    console.error("Test account service is not configured");
    return respond(503, { code: "service_unavailable" });
  }

  try {
    const raw = await request.text();
    if (new TextEncoder().encode(raw).byteLength > MAX_BODY_BYTES) {
      return respond(413, { code: "request_too_large" });
    }
    const body = JSON.parse(raw);
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      return respond(400, { code: "invalid_request" });
    }
    const action = body.action;
    const window = testWindow();
    if (action === "status") {
      return respond(200, { active: window.active, until: window.until });
    }
    if (!["send_registration", "complete_registration", "send_login", "check_login"].includes(action)) {
      return respond(400, { code: "invalid_request" });
    }
    if (action.endsWith("registration") && !window.active) {
      return respond(403, { code: "test_window_closed" });
    }

    const phone = String(body.phone ?? "").trim();
    const email = String(body.email ?? "").trim().toLowerCase();
    const code = String(body.code ?? "").trim();
    if (!PHONE.test(phone) ||
        (action.endsWith("registration") && !EMAIL.test(email)) ||
        (action.startsWith("complete") || action.startsWith("check")) &&
          !CODE.test(code)) {
      return respond(400, { code: "invalid_request" });
    }
    const admin = createClient(url, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: accounts, error: accountsError } = await admin.rpc(
      "test_duplicate_accounts_by_phone",
      { contact_phone: phone },
    );
    if (accountsError) {
      console.error("Test account lookup failed", { code: accountsError.code });
      return respond(503, { code: "service_unavailable" });
    }
    const rows = accountRows(accounts);
    if (rows.length === 0) return respond(403, { code: "account_unavailable" });

    if (action.endsWith("registration")) {
      const { data: sourceExists, error: sourceError } = await admin.rpc(
        "test_duplicate_source_exists",
        { contact_email: email, contact_phone: phone },
      );
      if (sourceError) {
        console.error("Test account source lookup failed", { code: sourceError.code });
        return respond(503, { code: "service_unavailable" });
      }
      if (sourceExists !== true) {
        return respond(403, { code: "source_account_unavailable" });
      }
    }

    const credentials = btoa(`${twilioSid}:${twilioSecret}`);
    if (action.startsWith("send")) {
      const { data: allowed, error: limitError } = await admin.rpc(
        "claim_test_duplicate_sms_send",
        { contact_phone: phone },
      );
      if (limitError) {
        console.error("Test account SMS limit failed", { code: limitError.code });
        return respond(503, { code: "service_unavailable" });
      }
      if (allowed !== true) return respond(429, { code: "sms_rate_limited" });
      const sent = await twilioVerify("send", phone, "", verifySid, credentials);
      return respond(sent.status, { code: sent.ok ? "code_sent" : sent.error });
    }

    if (action === "complete_registration") {
      const password = String(body.password ?? "");
      const metadata = body.metadata;
      if (password.length < 8 || password.length > 1024 ||
          !metadata || typeof metadata !== "object" || Array.isArray(metadata) ||
          typeof metadata.first_name !== "string" ||
          metadata.first_name.trim().length < 2 ||
          typeof metadata.date_of_birth !== "string" ||
          typeof metadata.country_code !== "string" ||
          typeof metadata.legal_accepted_at !== "string" ||
          !metadata.accepted_legal_documents ||
          typeof metadata.accepted_legal_documents !== "object") {
        return respond(400, { code: "invalid_request" });
      }
      const birthDate = Date.parse(metadata.date_of_birth);
      const now = new Date();
      const adultCutoff = Date.UTC(
        now.getUTCFullYear() - 18,
        now.getUTCMonth(),
        now.getUTCDate(),
      );
      if (!/^\d{4}-\d{2}-\d{2}$/.test(metadata.date_of_birth) ||
          !Number.isFinite(birthDate) || birthDate > adultCutoff) {
        return respond(403, { code: "age_ineligible" });
      }
      const verified = await twilioVerify("check", phone, code, verifySid, credentials);
      if (!verified.ok) return respond(verified.status, { code: verified.error });
      const alias = `test-${crypto.randomUUID()}@accounts.maplov.ca`;
      const { data: created, error: createError } =
        await admin.auth.admin.createUser({
          email: alias,
          password,
          email_confirm: true,
          user_metadata: {
            ...metadata,
            phone_number: phone,
          },
          app_metadata: {
            maplov_test_duplicate: true,
            maplov_test_phone_verified: true,
            maplov_contact_phone: phone,
            maplov_contact_email: email,
            maplov_contact_email_verified: true,
            maplov_test_created_at: new Date().toISOString(),
          },
        });
      if (createError || !created.user) {
        console.error("Test account creation failed", {
          code: createError?.code,
          status: createError?.status,
        });
        return respond(503, { code: "account_creation_failed" });
      }
      return respond(200, { code: "account_created", auth_email: alias });
    }

    const verified = await twilioVerify("check", phone, code, verifySid, credentials);
    if (!verified.ok) return respond(verified.status, { code: verified.error });
    return respond(200, {
      code: "accounts_ready",
      accounts: rows.map((row) => ({
        id: row.account_id,
        auth_email: row.auth_email,
        contact_email: row.contact_email,
        name: row.account_name,
        created_at: row.created_at,
      })),
    });
  } catch (error) {
    console.error("Test account request failed", {
      category: error instanceof SyntaxError ? "invalid_json" : "internal_error",
    });
    return respond(error instanceof SyntaxError ? 400 : 503, {
      code: error instanceof SyntaxError ? "invalid_request" : "service_unavailable",
    });
  }
});
