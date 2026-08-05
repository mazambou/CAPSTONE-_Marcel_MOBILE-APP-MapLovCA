import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  adminClient,
  allowedCheckoutOrigin,
  applyVerifiedExternalEvent,
  corsHeaders,
  environmentEnabled,
  flutterwaveRequest,
  paypalEnvironment,
  requiredEnv,
  stripeRequest,
} from "../_shared/external_billing.ts";

function json(
  body: Record<string, unknown>,
  status: number,
  origin: string,
): Response {
  return Response.json(body, {
    status,
    headers: corsHeaders(origin),
  });
}

function trustedManagementUrl(value: unknown, domain: string): string {
  if (typeof value !== "string") {
    throw new Error("Provider returned no management URL");
  }
  const url = new URL(value);
  const trusted = url.hostname === domain ||
    url.hostname.endsWith(`.${domain}`);
  if (url.protocol !== "https:" || !trusted) {
    throw new Error("Provider returned an unexpected management URL");
  }
  return url.toString();
}

async function stripePortal(
  externalSubscriptionId: string,
): Promise<string> {
  const subscriptionResponse = await stripeRequest(
    `/v1/subscriptions/${encodeURIComponent(externalSubscriptionId)}`,
  );
  const subscription = await subscriptionResponse.json();
  if (!subscriptionResponse.ok || !subscription.customer) {
    throw new Error("Stripe subscription lookup failed");
  }
  const returnUrl = new URL(requiredEnv("EXTERNAL_BILLING_RETURN_URL"));
  if (returnUrl.protocol !== "https:") {
    throw new Error("EXTERNAL_BILLING_RETURN_URL must use HTTPS");
  }
  const form = new URLSearchParams({
    customer: String(subscription.customer),
    return_url: returnUrl.toString(),
  });
  const portalResponse = await stripeRequest("/v1/billing_portal/sessions", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: form,
  });
  const portal = await portalResponse.json();
  if (!portalResponse.ok) {
    throw new Error(`Stripe portal failed (${portalResponse.status})`);
  }
  return trustedManagementUrl(portal.url, "stripe.com");
}

Deno.serve(async (request) => {
  const origin = allowedCheckoutOrigin(request);
  if (!origin) {
    return Response.json({ error: "This billing origin is not allowed" }, {
      status: 403,
    });
  }
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(origin) });
  }
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405, origin);
  }
  if (!environmentEnabled("EXTERNAL_CHECKOUT_ENABLED")) {
    return json({ error: "External billing is disabled" }, 503, origin);
  }

  try {
    const authorization = request.headers.get("Authorization");
    if (!authorization) {
      return json({ error: "Authentication required" }, 401, origin);
    }
    const userClient = createClient(
      requiredEnv("SUPABASE_URL"),
      requiredEnv("SUPABASE_ANON_KEY"),
      { global: { headers: { Authorization: authorization } } },
    );
    const { data: { user }, error: userError } = await userClient.auth
      .getUser();
    if (userError || !user) {
      return json({ error: "Invalid session" }, 401, origin);
    }

    const admin = adminClient();
    const { data: subscription, error: subscriptionError } = await admin
      .from("subscriptions")
      .select(
        "id, provider, external_subscription_id, product_id, status, current_period_start, current_period_end, auto_renew_enabled, receipt_metadata",
      )
      .eq("user_id", user.id)
      .eq("is_current", true)
      .in("provider", ["stripe", "paypal", "flutterwave"])
      .maybeSingle();
    if (subscriptionError) throw new Error(subscriptionError.message);
    if (!subscription?.external_subscription_id) {
      return json({ error: "No external subscription was found" }, 404, origin);
    }

    const payload = await request.json();
    const action = String(payload.action ?? "portal");
    const provider = String(subscription.provider);
    if (action === "portal" && provider === "stripe") {
      const portalUrl = await stripePortal(
        subscription.external_subscription_id,
      );
      return json({ provider, portalUrl }, 200, origin);
    }
    if (action === "portal" && provider === "paypal") {
      const host = paypalEnvironment() === "production"
        ? "https://www.paypal.com"
        : "https://www.sandbox.paypal.com";
      return json(
        {
          provider,
          portalUrl: `${host}/myaccount/autopay/`,
        },
        200,
        origin,
      );
    }
    if (action !== "cancel" || provider !== "flutterwave") {
      return json({ error: "Unsupported billing action" }, 400, origin);
    }

    if (subscription.auto_renew_enabled === true) {
      const flutterwaveId = String(subscription.external_subscription_id)
        .replace(/^flutterwave:/, "");
      const cancellation = await flutterwaveRequest(
        `/v3/subscriptions/${encodeURIComponent(flutterwaveId)}/cancel`,
        { method: "PUT", body: JSON.stringify({}) },
      );
      const cancellationBody = await cancellation.json();
      if (!cancellation.ok || cancellationBody.status !== "success") {
        throw new Error(
          `Flutterwave cancellation failed (${cancellation.status})`,
        );
      }
    }

    const periodEnd = String(subscription.current_period_end ?? "");
    const providerProductId = String(
      subscription.receipt_metadata?.provider_product_id ?? "",
    );
    if (!periodEnd || !providerProductId) {
      throw new Error("Stored Flutterwave subscription is incomplete");
    }
    const stableCancellationId =
      `maplov:cancel:flutterwave:${subscription.id}:${periodEnd}`;
    await applyVerifiedExternalEvent(admin, {
      provider: "flutterwave",
      providerEventId: stableCancellationId,
      eventType: "cancellation",
      checkoutReference: subscription.receipt_metadata?.checkout_reference ??
        undefined,
      externalSubscriptionId: subscription.external_subscription_id,
      providerTransactionId: stableCancellationId,
      providerProductId,
      status: "cancelled",
      periodStart: subscription.current_period_start ?? undefined,
      periodEnd,
      autoRenewEnabled: false,
      environment: requiredEnv("FLUTTERWAVE_SECRET_KEY").includes("_TEST")
        ? "sandbox"
        : "production",
      metadata: { cancellation_source: "authenticated_maplov_user" },
    });
    return json({ provider, cancelled: true }, 200, origin);
  } catch (error) {
    console.error("External subscription management failed", error);
    return json(
      { error: "Unable to manage the external subscription" },
      502,
      origin,
    );
  }
});
