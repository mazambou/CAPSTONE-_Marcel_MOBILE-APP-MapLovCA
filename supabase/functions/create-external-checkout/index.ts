import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  adminClient,
  allowedCheckoutOrigin,
  corsHeaders,
  environmentEnabled,
  ExternalProduct,
  ExternalProvider,
  flutterwaveRequest,
  paypalEnvironment,
  paypalRequest,
  productFor,
  requiredEnv,
  stripeCatalogEntry,
  stripeRequest,
  validStripePrice,
} from "../_shared/external_billing.ts";

type CheckoutResult = {
  providerSessionId: string;
  checkoutUrl: string;
  expiresAt?: string;
};

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

function configuredUrl(name: string): string {
  const value = requiredEnv(name);
  const url = new URL(value);
  if (url.protocol !== "https:") {
    throw new Error(`${name} must use HTTPS`);
  }
  return url.toString();
}

function checkoutUrlFor(
  provider: ExternalProvider,
  value: unknown,
): string {
  if (typeof value !== "string") {
    throw new Error("Provider returned no checkout URL");
  }
  const url = new URL(value);
  const allowedDomain = provider === "stripe"
    ? "stripe.com"
    : provider === "paypal"
    ? "paypal.com"
    : "flutterwave.com";
  const expectedHost = url.hostname === allowedDomain ||
    url.hostname.endsWith(`.${allowedDomain}`);
  if (url.protocol !== "https:" || !expectedHost) {
    throw new Error("Provider returned an unexpected checkout URL");
  }
  return url.toString();
}

async function createStripeCheckout(
  reference: string,
  userId: string,
  userEmail: string,
  product: ExternalProduct,
): Promise<CheckoutResult> {
  const successUrl = new URL(configuredUrl("EXTERNAL_CHECKOUT_SUCCESS_URL"));
  successUrl.searchParams.set("provider", "stripe");
  successUrl.searchParams.set("checkout", "{CHECKOUT_SESSION_ID}");
  successUrl.searchParams.set("reference", reference);
  const cancelUrl = new URL(configuredUrl("EXTERNAL_CHECKOUT_CANCEL_URL"));
  cancelUrl.searchParams.set("provider", "stripe");
  cancelUrl.searchParams.set("cancelled", "true");
  cancelUrl.searchParams.set("reference", reference);

  const form = new URLSearchParams({
    mode: product.billingMode,
    success_url: successUrl.toString(),
    cancel_url: cancelUrl.toString(),
    client_reference_id: userId,
    customer_email: userEmail,
    "line_items[0][price]": product.providerProductId,
    "line_items[0][quantity]": "1",
    "metadata[maplov_checkout_reference]": reference,
  });
  if (product.billingMode === "subscription") {
    form.set(
      "subscription_data[metadata][maplov_checkout_reference]",
      reference,
    );
    form.set("subscription_data[metadata][maplov_user_id]", userId);
  } else {
    form.set(
      "payment_intent_data[metadata][maplov_checkout_reference]",
      reference,
    );
    form.set("payment_intent_data[metadata][maplov_user_id]", userId);
    form.set("submit_type", "pay");
  }
  const response = await stripeRequest("/v1/checkout/sessions", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      "Idempotency-Key": reference,
    },
    body: form,
  });
  const body = await response.json();
  if (!response.ok) {
    throw new Error(`Stripe checkout failed (${response.status})`);
  }
  return {
    providerSessionId: String(body.id),
    checkoutUrl: checkoutUrlFor("stripe", body.url),
    expiresAt: body.expires_at
      ? new Date(Number(body.expires_at) * 1000).toISOString()
      : undefined,
  };
}

async function createPayPalCheckout(
  reference: string,
  product: ExternalProduct,
): Promise<CheckoutResult> {
  const returnUrl = new URL(configuredUrl("EXTERNAL_CHECKOUT_SUCCESS_URL"));
  returnUrl.searchParams.set("provider", "paypal");
  returnUrl.searchParams.set("reference", reference);
  const cancelUrl = new URL(configuredUrl("EXTERNAL_CHECKOUT_CANCEL_URL"));
  cancelUrl.searchParams.set("provider", "paypal");
  cancelUrl.searchParams.set("cancelled", "true");
  cancelUrl.searchParams.set("reference", reference);

  const response = await paypalRequest("/v1/billing/subscriptions", {
    method: "POST",
    headers: {
      "PayPal-Request-Id": reference,
      "Prefer": "return=representation",
    },
    body: JSON.stringify({
      plan_id: product.providerProductId,
      custom_id: reference,
      application_context: {
        brand_name: "MapLov",
        user_action: "SUBSCRIBE_NOW",
        shipping_preference: "NO_SHIPPING",
        return_url: returnUrl.toString(),
        cancel_url: cancelUrl.toString(),
      },
    }),
  });
  const body = await response.json();
  if (!response.ok) {
    throw new Error(`PayPal checkout failed (${response.status})`);
  }
  const approval = Array.isArray(body.links)
    ? body.links.find((link: Record<string, unknown>) => link.rel === "approve")
    : undefined;
  return {
    providerSessionId: String(body.id),
    checkoutUrl: checkoutUrlFor("paypal", approval?.href),
  };
}

async function createFlutterwaveCheckout(
  reference: string,
  userEmail: string,
  displayName: string,
  product: ExternalProduct,
): Promise<CheckoutResult> {
  if (product.amountMinor === undefined || !product.currencyCode) {
    throw new Error("Flutterwave amount configuration is missing");
  }
  const redirectUrl = new URL(configuredUrl("EXTERNAL_CHECKOUT_SUCCESS_URL"));
  redirectUrl.searchParams.set("provider", "flutterwave");
  redirectUrl.searchParams.set("reference", reference);
  const numericPlanId = Number(product.providerProductId);
  const paymentPlan = Number.isSafeInteger(numericPlanId)
    ? numericPlanId
    : product.providerProductId;

  const response = await flutterwaveRequest("/v3/payments", {
    method: "POST",
    body: JSON.stringify({
      tx_ref: reference,
      amount: (product.amountMinor / 100).toFixed(2),
      currency: product.currencyCode,
      redirect_url: redirectUrl.toString(),
      payment_plan: paymentPlan,
      customer: {
        email: userEmail,
        name: displayName,
      },
      customizations: {
        title: `MapLov ${product.tier === "plus" ? "Plus" : "VIP"}`,
        description: "Abonnement mensuel MapLov",
      },
      meta: {
        maplov_checkout_reference: reference,
      },
    }),
  });
  const body = await response.json();
  if (!response.ok || body.status !== "success") {
    throw new Error(`Flutterwave checkout failed (${response.status})`);
  }
  return {
    providerSessionId: reference,
    checkoutUrl: checkoutUrlFor("flutterwave", body.data?.link),
  };
}

Deno.serve(async (request) => {
  const origin = allowedCheckoutOrigin(request);
  if (!origin) {
    return Response.json({ error: "This checkout origin is not allowed" }, {
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
    return json({ error: "External checkout is disabled" }, 503, origin);
  }

  const admin = adminClient();
  let checkoutId: string | undefined;
  try {
    const authHeader = request.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Authentication required" }, 401, origin);
    }
    const userClient = createClient(
      requiredEnv("SUPABASE_URL"),
      requiredEnv("SUPABASE_ANON_KEY"),
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: { user }, error: userError } = await userClient.auth
      .getUser();
    if (userError || !user?.email) {
      return json({ error: "A valid account email is required" }, 401, origin);
    }

    const payload = await request.json();
    const provider = String(payload.provider ?? "") as ExternalProvider;
    const legacyTier = String(payload.tier ?? "");
    const requestedProductId = String(
      payload.productId ??
        (legacyTier === "plus"
          ? "maplov_plus_monthly"
          : legacyTier === "vip"
          ? "maplov_vip_monthly"
          : ""),
    );
    if (!["stripe", "paypal", "flutterwave"].includes(provider)) {
      return json({ error: "Unsupported payment provider" }, 400, origin);
    }
    let product: ExternalProduct;
    try {
      product = await productFor(provider, requestedProductId);
    } catch (error) {
      if (
        error instanceof Error &&
        error.message.startsWith("Unsupported MapLov")
      ) {
        return json({ error: "Unsupported payment product" }, 400, origin);
      }
      throw error;
    }
    let promotionId: string | undefined;
    if (provider === "stripe") {
      const now = new Date().toISOString();
      const { data: promotion, error: promotionError } = await admin
        .from("billing_promotions")
        .select(
          "id, stripe_price_id, promotional_amount_minor, currency_code",
        )
        .eq("product_id", product.productId)
        .eq("is_enabled", true)
        .lte("starts_at", now)
        .gt("ends_at", now)
        .order("promotional_amount_minor", { ascending: true })
        .limit(1)
        .maybeSingle();
      if (promotionError && promotionError.code !== "42P01") {
        throw new Error(promotionError.message);
      }
      if (promotion?.stripe_price_id) {
        const promotionalPriceResponse = await stripeRequest(
          `/v1/prices/${encodeURIComponent(String(promotion.stripe_price_id))}`,
        );
        const promotionalPrice = await promotionalPriceResponse.json();
        const promotionalEntry = {
          ...stripeCatalogEntry(product.productId),
          amountMinor: Number(promotion.promotional_amount_minor),
        };
        if (
          !promotionalPriceResponse.ok ||
          !validStripePrice(promotionalPrice, promotionalEntry)
        ) {
          throw new Error("Stripe promotional price configuration is invalid");
        }
        product = {
          ...product,
          providerProductId: String(promotion.stripe_price_id),
          amountMinor: Number(promotion.promotional_amount_minor),
          currencyCode: String(promotion.currency_code).toUpperCase(),
        };
        promotionId = String(promotion.id);
      }
    }

    if (product.billingMode === "subscription") {
      const { data: currentSubscription, error: currentError } = await admin
        .from("subscriptions")
        .select("id")
        .eq("user_id", user.id)
        .eq("is_current", true)
        .maybeSingle();
      if (currentError) throw new Error(currentError.message);
      if (currentSubscription) {
        return json(
          {
            error:
              "An active subscription already exists. Manage it before purchasing another plan.",
          },
          409,
          origin,
        );
      }
    }

    const tenMinutesAgo = new Date(Date.now() - 10 * 60 * 1000).toISOString();
    const { count, error: countError } = await admin
      .from("external_checkout_sessions")
      .select("id", { count: "exact", head: true })
      .eq("user_id", user.id)
      .gte("created_at", tenMinutesAgo);
    if (countError) throw new Error(countError.message);
    if ((count ?? 0) >= 5) {
      return json(
        { error: "Too many checkout attempts. Please try again later." },
        429,
        origin,
      );
    }

    // A UUID is also used as PayPal's idempotency key. PayPal recommends the
    // UUID format because PayPal-Request-Id is limited to 38 single-byte
    // characters.
    const reference = crypto.randomUUID();
    const { data: checkout, error: insertError } = await admin
      .from("external_checkout_sessions")
      .insert({
        user_id: user.id,
        provider,
        billing_mode: product.billingMode,
        tier: product.tier ?? null,
        product_id: product.productId,
        provider_product_id: product.providerProductId,
        duration_seconds: product.durationSeconds ?? null,
        quantity: product.quantity ?? null,
        promotion_id: promotionId ?? null,
        checkout_reference: reference,
        amount_minor: product.amountMinor ?? null,
        currency_code: product.currencyCode ?? null,
      })
      .select("id")
      .single();
    if (insertError) throw new Error(insertError.message);
    checkoutId = checkout.id as string;

    const displayName = String(
      user.user_metadata?.full_name ??
        user.user_metadata?.name ??
        user.email.split("@")[0],
    ).substring(0, 100);
    const result = provider === "stripe"
      ? await createStripeCheckout(reference, user.id, user.email, product)
      : provider === "paypal"
      ? await createPayPalCheckout(reference, product)
      : await createFlutterwaveCheckout(
        reference,
        user.email,
        displayName,
        product,
      );

    const { error: updateError } = await admin
      .from("external_checkout_sessions")
      .update({
        provider_session_id: result.providerSessionId,
        status: "pending",
        expires_at: result.expiresAt ?? null,
        updated_at: new Date().toISOString(),
      })
      .eq("id", checkoutId);
    if (updateError) throw new Error(updateError.message);

    return json(
      {
        provider,
        productId: product.productId,
        billingMode: product.billingMode,
        promotionId,
        checkoutUrl: result.checkoutUrl,
        reference,
        environment: provider === "paypal" ? paypalEnvironment() : undefined,
      },
      200,
      origin,
    );
  } catch (error) {
    if (checkoutId) {
      await admin
        .from("external_checkout_sessions")
        .update({ status: "failed", updated_at: new Date().toISOString() })
        .eq("id", checkoutId);
    }
    console.error("External checkout creation failed", error);
    return json(
      { error: "Unable to create a secure checkout session" },
      502,
      origin,
    );
  }
});
