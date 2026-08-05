import {
  createClient,
  SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2";

export type ExternalProvider = "stripe" | "paypal" | "flutterwave";
export type ExternalTier = "plus" | "vip";
export type ExternalBillingMode = "subscription" | "payment";
export type ExternalEventType =
  | "purchase"
  | "restore"
  | "renewal"
  | "cancellation"
  | "expiration"
  | "refund"
  | "billing_issue"
  | "recovery"
  | "plan_change";

export type ExternalSubscriptionStatus =
  | "pending"
  | "active"
  | "past_due"
  | "cancelled"
  | "expired"
  | "refunded";

export type VerifiedExternalEvent = {
  provider: ExternalProvider;
  providerEventId: string;
  eventType: ExternalEventType;
  checkoutReference?: string;
  externalSubscriptionId: string;
  providerTransactionId: string;
  providerProductId: string;
  status: ExternalSubscriptionStatus;
  periodStart?: string;
  periodEnd?: string;
  autoRenewEnabled: boolean;
  amountMinor?: number;
  currencyCode?: string;
  environment?: string;
  metadata: Record<string, unknown>;
};

export type ExternalProduct = {
  billingMode: ExternalBillingMode;
  tier?: ExternalTier;
  productId: string;
  providerProductId: string;
  durationSeconds?: number;
  quantity?: number;
  amountMinor?: number;
  currencyCode?: string;
};

export type StripeCatalogEntry = {
  productId: string;
  name: string;
  description: string;
  amountMinor: number;
  billingMode: ExternalBillingMode;
  tier?: ExternalTier;
  interval?: "month" | "year";
  durationSeconds?: number;
  quantity?: number;
};

export const stripeCatalog: readonly StripeCatalogEntry[] = [
  {
    productId: "maplov_plus_monthly",
    name: "MapLov Plus – Mensuel",
    description: "Abonnement MapLov Plus renouvelé chaque mois.",
    amountMinor: 1299,
    billingMode: "subscription",
    tier: "plus",
    interval: "month",
  },
  {
    productId: "maplov_plus_yearly",
    name: "MapLov Plus – Annuel",
    description: "Abonnement MapLov Plus renouvelé chaque année.",
    amountMinor: 9999,
    billingMode: "subscription",
    tier: "plus",
    interval: "year",
  },
  {
    productId: "maplov_vip_monthly",
    name: "MapLov VIP – Mensuel",
    description: "Abonnement MapLov VIP renouvelé chaque mois.",
    amountMinor: 1999,
    billingMode: "subscription",
    tier: "vip",
    interval: "month",
  },
  {
    productId: "maplov_vip_yearly",
    name: "MapLov VIP – Annuel",
    description: "Abonnement MapLov VIP renouvelé chaque année.",
    amountMinor: 14999,
    billingMode: "subscription",
    tier: "vip",
    interval: "year",
  },
  {
    productId: "maplov_country_pass_24h",
    name: "Country Pass – 24 heures",
    description: "Recherche Country MapLov pendant 24 heures.",
    amountMinor: 299,
    billingMode: "payment",
    durationSeconds: 86_400,
  },
  {
    productId: "maplov_country_pass_7d",
    name: "Country Pass – 7 jours",
    description: "Recherche Country MapLov pendant 7 jours.",
    amountMinor: 699,
    billingMode: "payment",
    durationSeconds: 604_800,
  },
  {
    productId: "maplov_international_pass_24h",
    name: "International Pass – 24 heures",
    description: "Recherche internationale MapLov pendant 24 heures.",
    amountMinor: 499,
    billingMode: "payment",
    durationSeconds: 86_400,
  },
  {
    productId: "maplov_international_pass_7d",
    name: "International Pass – 7 jours",
    description: "Recherche internationale MapLov pendant 7 jours.",
    amountMinor: 999,
    billingMode: "payment",
    durationSeconds: 604_800,
  },
  {
    productId: "maplov_boost_30m",
    name: "Boost – 30 minutes",
    description: "Visibilité renforcée du profil pendant 30 minutes.",
    amountMinor: 299,
    billingMode: "payment",
    durationSeconds: 1_800,
  },
  {
    productId: "maplov_boost_3h",
    name: "Boost – 3 heures",
    description: "Visibilité renforcée du profil pendant 3 heures.",
    amountMinor: 499,
    billingMode: "payment",
    durationSeconds: 10_800,
  },
  {
    productId: "maplov_boost_24h",
    name: "Boost – 24 heures",
    description: "Visibilité renforcée du profil pendant 24 heures.",
    amountMinor: 799,
    billingMode: "payment",
    durationSeconds: 86_400,
  },
  {
    productId: "maplov_super_likes_5",
    name: "Pack Super Likes ×5",
    description: "Pack de 5 Super Likes MapLov.",
    amountMinor: 299,
    billingMode: "payment",
    quantity: 5,
  },
  {
    productId: "maplov_super_likes_15",
    name: "Pack Super Likes ×15",
    description: "Pack de 15 Super Likes MapLov.",
    amountMinor: 699,
    billingMode: "payment",
    quantity: 15,
  },
  {
    productId: "maplov_super_likes_30",
    name: "Pack Super Likes ×30",
    description: "Pack de 30 Super Likes MapLov.",
    amountMinor: 1199,
    billingMode: "payment",
    quantity: 30,
  },
] as const;

export type VerifiedOneTimePayment = {
  provider: ExternalProvider;
  providerEventId: string;
  checkoutReference: string;
  providerTransactionId: string;
  providerProductId: string;
  amountMinor?: number;
  currencyCode?: string;
  environment?: string;
  metadata: Record<string, unknown>;
};

export function requiredEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`${name} is not configured`);
  return value;
}

export function environmentEnabled(name: string): boolean {
  return Deno.env.get(name)?.trim().toLowerCase() === "true";
}

export function adminClient(): SupabaseClient {
  return createClient(
    requiredEnv("SUPABASE_URL"),
    requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
}

export async function planFor(
  provider: ExternalProvider,
  tier: ExternalTier,
): Promise<ExternalProduct> {
  return await productFor(
    provider,
    tier === "plus" ? "maplov_plus_monthly" : "maplov_vip_monthly",
  );
}

export async function productFor(
  provider: ExternalProvider,
  productId: string,
): Promise<ExternalProduct> {
  const subscriptions: Record<string, { tier: ExternalTier; suffix: string }> =
    {
      maplov_plus_monthly: { tier: "plus", suffix: "PLUS" },
      maplov_plus_yearly: { tier: "plus", suffix: "PLUS_YEARLY" },
      maplov_vip_monthly: { tier: "vip", suffix: "VIP" },
      maplov_vip_yearly: { tier: "vip", suffix: "VIP_YEARLY" },
    };
  const oneTimeProducts: Record<
    string,
    { suffix: string; durationSeconds?: number; quantity?: number }
  > = {
    maplov_country_pass_24h: {
      suffix: "COUNTRY_PASS_24H",
      durationSeconds: 86_400,
    },
    maplov_country_pass_7d: {
      suffix: "COUNTRY_PASS_7D",
      durationSeconds: 604_800,
    },
    maplov_international_pass_24h: {
      suffix: "INTERNATIONAL_PASS_24H",
      durationSeconds: 86_400,
    },
    maplov_international_pass_7d: {
      suffix: "INTERNATIONAL_PASS_7D",
      durationSeconds: 604_800,
    },
    maplov_boost_30m: { suffix: "BOOST_30M", durationSeconds: 1_800 },
    maplov_boost_3h: { suffix: "BOOST_3H", durationSeconds: 10_800 },
    maplov_boost_24h: { suffix: "BOOST_24H", durationSeconds: 86_400 },
    maplov_super_likes_5: { suffix: "SUPER_LIKES_5", quantity: 5 },
    maplov_super_likes_15: { suffix: "SUPER_LIKES_15", quantity: 15 },
    maplov_super_likes_30: { suffix: "SUPER_LIKES_30", quantity: 30 },
  };
  const subscription = subscriptions[productId];
  if (subscription) {
    if (provider !== "stripe" && productId.endsWith("_yearly")) {
      throw new Error(`${provider} does not support yearly MapLov products`);
    }
    const providerProductId = provider === "stripe"
      ? await stripePriceId(productId)
      : provider === "paypal"
      ? requiredEnv(`PAYPAL_${subscription.suffix}_PLAN_ID`)
      : requiredEnv(`FLUTTERWAVE_${subscription.suffix}_PLAN_ID`);
    const result: ExternalProduct = {
      billingMode: "subscription",
      tier: subscription.tier,
      productId,
      providerProductId,
    };
    if (provider === "stripe") {
      const catalog = stripeCatalogEntry(productId);
      return {
        ...result,
        amountMinor: catalog.amountMinor,
        currencyCode: "CAD",
      };
    }
    if (provider !== "flutterwave") return result;

    const amountMinor = Number(
      requiredEnv(`FLUTTERWAVE_${subscription.suffix}_AMOUNT_MINOR`),
    );
    if (!Number.isSafeInteger(amountMinor) || amountMinor <= 0) {
      throw new Error("Flutterwave amount must be a positive integer");
    }
    const currencyCode = requiredEnv("FLUTTERWAVE_CURRENCY").toUpperCase();
    if (!/^[A-Z]{3}$/.test(currencyCode)) {
      throw new Error("FLUTTERWAVE_CURRENCY must be a three-letter code");
    }
    return { ...result, amountMinor, currencyCode };
  }

  const oneTime = oneTimeProducts[productId];
  if (!oneTime) throw new Error("Unsupported MapLov product");
  if (provider !== "stripe") {
    throw new Error("One-time MapLov products are available through Stripe");
  }
  return {
    billingMode: "payment",
    productId,
    providerProductId: await stripePriceId(productId),
    durationSeconds: oneTime.durationSeconds,
    quantity: oneTime.quantity,
    amountMinor: stripeCatalogEntry(productId).amountMinor,
    currencyCode: "CAD",
  };
}

export function stripeCatalogEntry(productId: string): StripeCatalogEntry {
  const entry = stripeCatalog.find((item) => item.productId === productId);
  if (!entry) throw new Error("Unsupported MapLov Stripe product");
  return entry;
}

export function validStripePrice(
  price: Record<string, any>,
  entry: StripeCatalogEntry,
): boolean {
  const recurring = price.recurring as Record<string, unknown> | null;
  return price.active === true &&
    Number(price.unit_amount) === entry.amountMinor &&
    String(price.currency).toUpperCase() === "CAD" &&
    (entry.billingMode === "subscription"
      ? price.type === "recurring" && recurring?.interval === entry.interval
      : price.type === "one_time" && recurring == null);
}

export async function stripePriceByLookupKey(
  productId: string,
): Promise<Record<string, any> | null> {
  const query = new URLSearchParams({ active: "true", limit: "2" });
  query.append("lookup_keys[]", productId);
  const response = await stripeRequest(`/v1/prices?${query.toString()}`);
  const body = await response.json();
  if (!response.ok || !Array.isArray(body.data)) {
    throw new Error(`Stripe price lookup failed (${response.status})`);
  }
  if (body.data.length > 1) {
    throw new Error(`Stripe lookup key is ambiguous: ${productId}`);
  }
  return body.data[0] ?? null;
}

export async function stripePriceId(productId: string): Promise<string> {
  const entry = stripeCatalogEntry(productId);
  const price = await stripePriceByLookupKey(productId);
  if (!price) {
    throw new Error(
      `Stripe product ${productId} is not synchronized; run sync-stripe-catalog`,
    );
  }
  if (!validStripePrice(price, entry) || typeof price.id !== "string") {
    throw new Error(`Stripe price configuration is invalid: ${productId}`);
  }
  return price.id;
}

export async function applyVerifiedOneTimePayment(
  admin: SupabaseClient,
  event: VerifiedOneTimePayment,
): Promise<string> {
  const { data, error } = await admin.rpc("apply_external_one_time_payment", {
    provider_value: event.provider,
    provider_event_id_value: event.providerEventId,
    checkout_reference_value: event.checkoutReference,
    provider_transaction_id_value: event.providerTransactionId,
    provider_product_id_value: event.providerProductId,
    amount_minor_value: event.amountMinor ?? null,
    currency_code_value: event.currencyCode ?? null,
    environment_value: event.environment ?? null,
    metadata_value: event.metadata,
  });
  if (error) throw new Error(error.message);
  return data as string;
}

export function allowedCheckoutOrigin(request: Request): string | null {
  const origin = request.headers.get("Origin")?.trim();
  if (!origin) return null;
  const allowed = (Deno.env.get("EXTERNAL_CHECKOUT_ALLOWED_ORIGINS") ?? "")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);
  return allowed.includes(origin) ? origin : null;
}

export function corsHeaders(origin: string): HeadersInit {
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Headers":
      "authorization, apikey, content-type, x-client-info",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Max-Age": "86400",
    "Vary": "Origin",
  };
}

export async function applyVerifiedExternalEvent(
  admin: SupabaseClient,
  event: VerifiedExternalEvent,
): Promise<string> {
  const { data, error } = await admin.rpc("apply_external_subscription_event", {
    provider_value: event.provider,
    provider_event_id_value: event.providerEventId,
    event_type_value: event.eventType,
    checkout_reference_value: event.checkoutReference ?? null,
    external_subscription_id_value: event.externalSubscriptionId,
    provider_transaction_id_value: event.providerTransactionId,
    provider_product_id_value: event.providerProductId,
    status_value: event.status,
    period_start_value: event.periodStart ?? null,
    period_end_value: event.periodEnd ?? null,
    auto_renew_enabled_value: event.autoRenewEnabled,
    amount_minor_value: event.amountMinor ?? null,
    currency_code_value: event.currencyCode ?? null,
    environment_value: event.environment ?? null,
    metadata_value: event.metadata,
  });
  if (error) throw new Error(error.message);
  return data as string;
}

export function paypalBaseUrl(): string {
  return environmentEnabled("PAYPAL_LIVE_MODE")
    ? "https://api-m.paypal.com"
    : "https://api-m.sandbox.paypal.com";
}

export function paypalEnvironment(): "production" | "sandbox" {
  return environmentEnabled("PAYPAL_LIVE_MODE") ? "production" : "sandbox";
}

export async function paypalAccessToken(): Promise<string> {
  const credentials = btoa(
    `${requiredEnv("PAYPAL_CLIENT_ID")}:${requiredEnv("PAYPAL_CLIENT_SECRET")}`,
  );
  const response = await fetch(`${paypalBaseUrl()}/v1/oauth2/token`, {
    method: "POST",
    headers: {
      "Authorization": `Basic ${credentials}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials",
  });
  if (!response.ok) {
    throw new Error(`PayPal authentication failed (${response.status})`);
  }
  const body = await response.json();
  if (typeof body.access_token !== "string") {
    throw new Error("PayPal returned no access token");
  }
  return body.access_token;
}

export async function paypalRequest(
  path: string,
  init: RequestInit = {},
): Promise<Response> {
  const token = await paypalAccessToken();
  return fetch(`${paypalBaseUrl()}${path}`, {
    ...init,
    headers: {
      "Authorization": `Bearer ${token}`,
      "Content-Type": "application/json",
      ...(init.headers ?? {}),
    },
  });
}

export async function stripeRequest(
  path: string,
  init: RequestInit = {},
): Promise<Response> {
  return fetch(`https://api.stripe.com${path}`, {
    ...init,
    headers: {
      "Authorization": `Bearer ${requiredEnv("STRIPE_SECRET_KEY")}`,
      ...(init.headers ?? {}),
    },
  });
}

export async function flutterwaveRequest(
  path: string,
  init: RequestInit = {},
): Promise<Response> {
  return fetch(`https://api.flutterwave.com${path}`, {
    ...init,
    headers: {
      "Authorization": `Bearer ${requiredEnv("FLUTTERWAVE_SECRET_KEY")}`,
      "Content-Type": "application/json",
      ...(init.headers ?? {}),
    },
  });
}

function bytesEqual(left: Uint8Array, right: Uint8Array): boolean {
  if (left.length !== right.length) return false;
  let mismatch = 0;
  for (let index = 0; index < left.length; index += 1) {
    mismatch |= left[index] ^ right[index];
  }
  return mismatch === 0;
}

function hexBytes(value: string): Uint8Array | null {
  if (!/^[0-9a-f]+$/i.test(value) || value.length % 2 !== 0) return null;
  return Uint8Array.from(
    value.match(/.{2}/g)!.map((byte) => Number.parseInt(byte, 16)),
  );
}

function base64Bytes(value: string): Uint8Array | null {
  try {
    const decoded = atob(value);
    return Uint8Array.from(decoded, (character) => character.charCodeAt(0));
  } catch {
    return null;
  }
}

async function hmac(
  secret: string,
  payload: string,
): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(payload),
  );
  return new Uint8Array(signature);
}

export async function verifyStripeSignature(
  rawBody: string,
  signatureHeader: string | null,
): Promise<void> {
  if (!signatureHeader) throw new Error("Stripe signature is missing");
  const values = signatureHeader.split(",").map((part) => part.trim());
  const timestamp = values
    .find((part) => part.startsWith("t="))
    ?.substring(2);
  const signatures = values
    .filter((part) => part.startsWith("v1="))
    .map((part) => part.substring(3));
  const timestampNumber = Number(timestamp);
  if (
    !timestamp ||
    !Number.isFinite(timestampNumber) ||
    Math.abs(Date.now() / 1000 - timestampNumber) > 300
  ) {
    throw new Error("Stripe signature timestamp is invalid");
  }
  const expected = await hmac(
    requiredEnv("STRIPE_WEBHOOK_SECRET"),
    `${timestamp}.${rawBody}`,
  );
  const verified = signatures.some((value) => {
    const provided = hexBytes(value);
    return provided !== null && bytesEqual(expected, provided);
  });
  if (!verified) throw new Error("Stripe signature is invalid");
}

export async function verifyFlutterwaveSignature(
  rawBody: string,
  signatureHeader: string | null,
): Promise<void> {
  if (!signatureHeader) throw new Error("Flutterwave signature is missing");
  const expected = await hmac(
    requiredEnv("FLUTTERWAVE_SECRET_HASH"),
    rawBody,
  );
  const provided = base64Bytes(signatureHeader);
  if (provided === null || !bytesEqual(expected, provided)) {
    throw new Error("Flutterwave signature is invalid");
  }
}

export function isoFromUnix(value: unknown): string | undefined {
  const seconds = Number(value);
  if (!Number.isFinite(seconds) || seconds <= 0) return undefined;
  return new Date(seconds * 1000).toISOString();
}

export function isoFromValue(value: unknown): string | undefined {
  if (typeof value !== "string" || !value.trim()) return undefined;
  const milliseconds = Date.parse(value);
  if (!Number.isFinite(milliseconds)) return undefined;
  return new Date(milliseconds).toISOString();
}
