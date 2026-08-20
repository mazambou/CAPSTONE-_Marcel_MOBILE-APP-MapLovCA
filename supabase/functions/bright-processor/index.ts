import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const TWILIO_API_KEY_SID = Deno.env.get("TWILIO_VERIFY_API_KEY_SID");
const TWILIO_API_KEY_SECRET = Deno.env.get(
  "TWILIO_VERIFY_API_KEY_SECRET",
);
const TWILIO_VERIFY_SERVICE_SID = Deno.env.get(
  "TWILIO_VERIFY_SERVICE_SID",
);
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");
const AFRICAN_COUNTRY_CODES = new Set([
  "DZ", "AO", "BJ", "BW", "BF", "BI", "CV", "CM", "CF", "TD", "KM",
  "CG", "CD", "CI", "DJ", "EG", "GQ", "ER", "SZ", "ET", "GA", "GM",
  "GH", "GN", "GW", "KE", "LS", "LR", "LY", "MG", "MW", "ML", "MR",
  "MU", "MA", "MZ", "NA", "NE", "NG", "RW", "ST", "SN", "SC", "SL",
  "SO", "ZA", "SS", "SD", "TZ", "TG", "TN", "UG", "ZM", "ZW", "EH",
]);
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  // La fonction doit être appelée par un utilisateur Supabase authentifié.
  const authorization = req.headers.get("Authorization");

  if (!authorization?.startsWith("Bearer ")) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  if (
    !TWILIO_API_KEY_SID ||
    !TWILIO_API_KEY_SECRET ||
    !TWILIO_VERIFY_SERVICE_SID ||
    !SUPABASE_URL ||
    !SUPABASE_ANON_KEY
  ) {
    console.error("Missing Twilio environment variables");
    return jsonResponse({ error: "Server configuration error" }, 500);
  }

  try {
    const userClient = createClient(
      SUPABASE_URL,
      SUPABASE_ANON_KEY,
      {
        global: {
          headers: {
            Authorization: authorization,
          },
        },
      },
    );
    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();

    if (userError || !user) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const { data: profile } = await userClient.from("profiles")
      .select("country_code").eq("id", user.id).maybeSingle();
    const countryCode = String(
      profile?.country_code ?? user.user_metadata?.country_code ?? "",
    ).trim().toUpperCase();
    if (AFRICAN_COUNTRY_CODES.has(countryCode)) {
      return jsonResponse(
        { error: "Phone verification is not required in this country" },
        403,
      );
    }

    const body = await req.json();
    const phone = String(body.phone ?? "").trim();

    // Format international E.164
    // Exemple Canada : +14168350218
    if (!/^\+[1-9]\d{7,14}$/.test(phone)) {
      return jsonResponse(
        {
          error:
            "Invalid phone number. Use international format, for example +14168350218",
        },
        400,
      );
    }
    const authPhone = String(user.phone ?? "").trim();
    const metadataPhone = String(
      user.user_metadata?.phone_number ?? "",
    ).trim();
    const accountPhone = authPhone || metadataPhone;
    if (!accountPhone || accountPhone !== phone) {
      return jsonResponse({ error: "Phone number does not match account" }, 403);
    }

    const credentials = btoa(
      `${TWILIO_API_KEY_SID}:${TWILIO_API_KEY_SECRET}`,
    );

    const params = new URLSearchParams();
    params.set("To", phone);
    params.set("Channel", "sms");

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 8000);

    let response: Response;

    try {
      response = await fetch(
        `https://verify.twilio.com/v2/Services/${TWILIO_VERIFY_SERVICE_SID}/Verifications`,
        {
          method: "POST",
          headers: {
            Authorization: `Basic ${credentials}`,
            "Content-Type": "application/x-www-form-urlencoded",
          },
          body: params.toString(),
          signal: controller.signal,
        },
      );
    } finally {
      clearTimeout(timeout);
    }

    if (!response.ok) {
      let twilioCode: number | string | undefined;
      try {
        const error = await response.json();
        if (
          typeof error === "object" &&
          error !== null &&
          "code" in error &&
          (typeof error.code === "number" || typeof error.code === "string")
        ) {
          twilioCode = error.code;
        }
      } catch {
        // Do not expose or log Twilio's raw response body.
      }
      console.error(
        "Twilio Verify request failed",
        { httpStatus: response.status, twilioCode },
      );

      return jsonResponse(
        { error: "Unable to send verification code" },
        502,
      );
    }

    const result = await response.json();

    return jsonResponse({
      success: true,
      status: result.status,
    });
  } catch (error) {
    console.error(
      "send-phone-otp error:",
      error instanceof Error ? error.message : "Unknown error",
    );

    return jsonResponse(
      { error: "Unable to send verification code" },
      500,
    );
  }
});
