import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";
import {
  buildAuthEmails,
  type AuthEmailPayload,
  InvalidHookPayloadError,
  type OutgoingEmail,
} from "./email_content.ts";

const FROM_EMAIL = "noreply@maplov.ca";
const FROM_NAME = "MapLov";
const TWILIO_EMAIL_ENDPOINT = "https://comms.twilio.com/v1/Emails";
const MAX_PAYLOAD_BYTES = 64 * 1024;
const PROVIDER_TIMEOUT_MS = 4000;

class ConfigurationError extends Error {}
class SignatureVerificationError extends Error {}
class ProviderError extends Error {
  constructor(readonly status: number, readonly requestId?: string) {
    super(`Twilio Email API returned HTTP ${status}`);
  }
}

function environment(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new ConfigurationError(`Missing environment variable: ${name}`);
  return value;
}

function jsonError(status: number, httpCode: number, message: string): Response {
  return new Response(
    JSON.stringify({ error: { http_code: httpCode, message } }),
    { status, headers: { "Content-Type": "application/json" } },
  );
}

async function sendWithTwilio(
  email: OutgoingEmail,
  credentials: string,
  webhookId: string,
): Promise<void> {
  const response = await fetch(TWILIO_EMAIL_ENDPOINT, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Basic ${credentials}`,
    },
    body: JSON.stringify({
      from: { address: FROM_EMAIL, name: FROM_NAME },
      to: [{ address: email.to }],
      content: {
        subject: email.subject,
        html: email.html,
        text: email.text,
        headers: { "X-MapLov-Webhook-ID": webhookId },
      },
    }),
    signal: AbortSignal.timeout(PROVIDER_TIMEOUT_MS),
  });

  if (!response.ok) {
    throw new ProviderError(
      response.status,
      response.headers.get("x-twilio-request-id") ?? undefined,
    );
  }
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return new Response("Method not allowed", {
      status: 405,
      headers: { "Allow": "POST" },
    });
  }

  const contentLength = Number(request.headers.get("content-length") ?? "0");
  if (Number.isFinite(contentLength) && contentLength > MAX_PAYLOAD_BYTES) {
    return jsonError(413, 413, "Hook payload is too large");
  }

  const webhookId = request.headers.get("webhook-id") ?? "missing";

  try {
    const twilioKeySid = environment("TWILIO_API_KEY_SID");
    const twilioKeySecret = environment("TWILIO_API_KEY_SECRET");
    const signingSecret = environment("SEND_EMAIL_HOOK_SECRET").replace(
      /^v1,whsec_/,
      "",
    );
    const supabaseUrl = environment("SUPABASE_URL");

    const rawPayload = await request.text();
    if (new TextEncoder().encode(rawPayload).byteLength > MAX_PAYLOAD_BYTES) {
      return jsonError(413, 413, "Hook payload is too large");
    }

    const webhook = new Webhook(signingSecret);
    let payload: AuthEmailPayload;
    try {
      payload = webhook.verify(
        rawPayload,
        Object.fromEntries(request.headers),
      ) as AuthEmailPayload;
    } catch {
      throw new SignatureVerificationError("Invalid webhook signature");
    }
    const emails = buildAuthEmails(payload, supabaseUrl);
    const credentials = btoa(`${twilioKeySid}:${twilioKeySecret}`);

    // Parallel delivery keeps secure two-address email changes inside the
    // five-second Supabase HTTP Hook execution window.
    await Promise.all(
      emails.map((email) => sendWithTwilio(email, credentials, webhookId)),
    );

    console.info("Auth email accepted by Twilio", {
      webhook_id: webhookId,
      action: payload.email_data.email_action_type,
      message_count: emails.length,
    });
    return new Response(JSON.stringify({}), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    if (error instanceof ProviderError) {
      console.error("Twilio Email API rejected the request", {
        webhook_id: webhookId,
        status: error.status,
        provider_request_id: error.requestId,
      });
      return jsonError(502, 502, "The email provider rejected the request");
    }

    if (error instanceof ConfigurationError) {
      console.error("Auth email function configuration error", {
        webhook_id: webhookId,
        message: error.message,
      });
      return jsonError(500, 500, "Email delivery is not configured");
    }

    if (error instanceof InvalidHookPayloadError) {
      console.error("Invalid authenticated email hook payload", {
        webhook_id: webhookId,
        message: error.message,
      });
      return jsonError(422, 422, "Unsupported or incomplete email request");
    }

    if (error instanceof SignatureVerificationError) {
      console.warn("Rejected unsigned auth email hook request", {
        webhook_id: webhookId,
      });
      return jsonError(401, 401, "Invalid webhook signature");
    }

    const isTimeout = error instanceof DOMException && error.name === "TimeoutError";
    console.error("Auth email hook request failed", {
      webhook_id: webhookId,
      category: isTimeout ? "provider_timeout" : "internal_error",
    });
    return jsonError(
      isTimeout ? 504 : 500,
      isTimeout ? 504 : 500,
      isTimeout ? "The email provider timed out" : "Email delivery failed",
    );
  }
});
