import {
  adminClient,
  applyVerifiedExternalEvent,
  applyVerifiedOneTimePayment,
  environmentEnabled,
  ExternalEventType,
  ExternalProvider,
  ExternalSubscriptionStatus,
  flutterwaveRequest,
  isoFromUnix,
  isoFromValue,
  paypalEnvironment,
  paypalRequest,
  planFor,
  requiredEnv,
  stripeRequest,
  VerifiedExternalEvent,
  verifyFlutterwaveSignature,
  verifyStripeSignature,
} from "../_shared/external_billing.ts";

function json(body: Record<string, unknown>, status = 200): Response {
  return Response.json(body, { status });
}

function objectValue(value: unknown): Record<string, any> {
  if (typeof value !== "object" || value === null) return {};
  return value as Record<string, any>;
}

function integerMinor(value: unknown): number | undefined {
  const amount = Number(value);
  if (!Number.isFinite(amount) || amount < 0) return undefined;
  return Math.round(amount);
}

function decimalMinor(value: unknown): number | undefined {
  const amount = Number(value);
  if (!Number.isFinite(amount) || amount < 0) return undefined;
  return Math.round(amount * 100);
}

function stripeEventType(
  type: string,
  subscription: Record<string, any>,
): ExternalEventType | null {
  switch (type) {
    case "checkout.session.completed":
    case "checkout.session.async_payment_succeeded":
      return "purchase";
    case "invoice.paid":
    case "invoice.payment_succeeded":
      return "renewal";
    case "invoice.payment_failed":
      return "billing_issue";
    case "customer.subscription.deleted":
      return "expiration";
    case "customer.subscription.updated":
      if (subscription.cancel_at_period_end === true) return "cancellation";
      if (subscription.status === "active") return "recovery";
      return "plan_change";
    default:
      return null;
  }
}

function stripeStatus(
  subscription: Record<string, any>,
  eventType: ExternalEventType,
): ExternalSubscriptionStatus {
  if (eventType === "expiration") return "expired";
  if (eventType === "cancellation") return "cancelled";
  switch (String(subscription.status ?? "")) {
    case "active":
    case "trialing":
      return "active";
    case "past_due":
    case "unpaid":
    case "paused":
      return "past_due";
    case "canceled":
      return "expired";
    default:
      return "pending";
  }
}

function stripeSubscriptionId(
  type: string,
  object: Record<string, any>,
): string | null {
  if (type.startsWith("customer.subscription.")) {
    return typeof object.id === "string" ? object.id : null;
  }
  const parentSubscription = object.parent?.subscription_details?.subscription;
  const value = object.subscription ?? parentSubscription;
  return typeof value === "string" ? value : value?.id ?? null;
}

async function updateStripeCheckoutState(
  object: Record<string, any>,
  status: "pending" | "failed" | "expired",
): Promise<boolean> {
  const reference = object.metadata?.maplov_checkout_reference;
  if (typeof reference !== "string" || !reference) return false;
  const values: Record<string, unknown> = {
    status,
    updated_at: new Date().toISOString(),
  };
  if (object.object === "checkout.session" && typeof object.id === "string") {
    values.provider_session_id = object.id;
  }
  const { data, error } = await adminClient()
    .from("external_checkout_sessions")
    .update(values)
    .eq("provider", "stripe")
    .eq("checkout_reference", reference)
    .in("status", ["created", "pending"])
    .select("id")
    .maybeSingle();
  if (error) throw new Error(error.message);
  return data !== null;
}

async function stripeWebhook(
  request: Request,
  rawBody: string,
): Promise<boolean> {
  await verifyStripeSignature(
    rawBody,
    request.headers.get("Stripe-Signature"),
  );
  const event = JSON.parse(rawBody);
  const object = objectValue(event.data?.object);
  if (event.type === "checkout.session.expired") {
    return await updateStripeCheckoutState(object, "expired");
  }
  if (
    event.type === "checkout.session.async_payment_failed" ||
    event.type === "payment_intent.payment_failed"
  ) {
    return await updateStripeCheckoutState(object, "failed");
  }
  if (
    ["checkout.session.completed", "checkout.session.async_payment_succeeded"]
      .includes(event.type) && object.mode === "payment"
  ) {
    if (object.payment_status !== "paid") {
      // Delayed payment methods first emit checkout.session.completed and
      // later emit async_payment_succeeded or async_payment_failed.
      return await updateStripeCheckoutState(object, "pending");
    }
    const reference = object.metadata?.maplov_checkout_reference;
    if (typeof reference !== "string" || !reference) {
      throw new Error("Stripe one-time payment has no checkout reference");
    }
    const lineItemsResponse = await stripeRequest(
      `/v1/checkout/sessions/${encodeURIComponent(String(object.id))}` +
        "/line_items?limit=2",
    );
    const lineItems = await lineItemsResponse.json();
    if (!lineItemsResponse.ok) {
      throw new Error(
        `Stripe line item lookup failed (${lineItemsResponse.status})`,
      );
    }
    const items = Array.isArray(lineItems.data) ? lineItems.data : [];
    const providerProductId = items[0]?.price?.id;
    if (
      items.length !== 1 ||
      typeof providerProductId !== "string" ||
      Number(items[0]?.quantity) !== 1
    ) {
      throw new Error("Stripe one-time payment has unexpected line items");
    }
    await applyVerifiedOneTimePayment(adminClient(), {
      provider: "stripe",
      providerEventId: String(event.id),
      checkoutReference: reference,
      providerTransactionId: String(object.payment_intent ?? object.id),
      providerProductId,
      amountMinor: integerMinor(object.amount_total),
      currencyCode: typeof object.currency === "string"
        ? object.currency.toUpperCase()
        : undefined,
      environment: event.livemode === true ? "production" : "sandbox",
      metadata: {
        stripe_event_type: event.type,
        stripe_checkout_session_id: object.id,
        livemode: event.livemode === true,
      },
    });
    return true;
  }
  const subscriptionId = stripeSubscriptionId(String(event.type), object);
  if (!subscriptionId) return false;

  const response = await stripeRequest(
    `/v1/subscriptions/${encodeURIComponent(subscriptionId)}` +
      "?expand[]=latest_invoice",
  );
  const subscription = await response.json();
  if (!response.ok) {
    throw new Error(`Stripe subscription lookup failed (${response.status})`);
  }
  const eventType = stripeEventType(String(event.type), subscription);
  if (!eventType) return false;
  const item = subscription.items?.data?.[0];
  const providerProductId = item?.price?.id;
  if (typeof providerProductId !== "string") {
    throw new Error("Stripe subscription has no price");
  }
  const checkoutReference = subscription.metadata?.maplov_checkout_reference ??
    object.metadata?.maplov_checkout_reference;
  const invoice = object.object === "invoice"
    ? object
    : object.latest_invoice ?? subscription.latest_invoice;
  const transactionId = String(
    invoice?.payment_intent?.id ??
      invoice?.payment_intent ??
      invoice?.id ??
      object.payment_intent ??
      event.id,
  );
  const amountMinor = integerMinor(
    invoice?.amount_paid ?? object.amount_total,
  );
  const currency = invoice?.currency ?? object.currency;

  const verified: VerifiedExternalEvent = {
    provider: "stripe",
    providerEventId: String(event.id),
    eventType,
    checkoutReference: typeof checkoutReference === "string"
      ? checkoutReference
      : undefined,
    externalSubscriptionId: subscriptionId,
    providerTransactionId: transactionId,
    providerProductId,
    status: stripeStatus(subscription, eventType),
    periodStart: isoFromUnix(
      item?.current_period_start ?? subscription.current_period_start,
    ),
    periodEnd: isoFromUnix(
      item?.current_period_end ?? subscription.current_period_end,
    ),
    autoRenewEnabled: subscription.cancel_at_period_end !== true &&
      subscription.status !== "canceled",
    amountMinor,
    currencyCode: typeof currency === "string"
      ? currency.toUpperCase()
      : undefined,
    environment: event.livemode === true ? "production" : "sandbox",
    metadata: {
      stripe_event_type: event.type,
      livemode: event.livemode === true,
    },
  };
  await applyVerifiedExternalEvent(adminClient(), verified);
  return true;
}

async function verifyPayPalWebhook(
  request: Request,
  event: Record<string, unknown>,
): Promise<void> {
  const response = await paypalRequest(
    "/v1/notifications/verify-webhook-signature",
    {
      method: "POST",
      body: JSON.stringify({
        auth_algo: request.headers.get("paypal-auth-algo"),
        cert_url: request.headers.get("paypal-cert-url"),
        transmission_id: request.headers.get("paypal-transmission-id"),
        transmission_sig: request.headers.get("paypal-transmission-sig"),
        transmission_time: request.headers.get("paypal-transmission-time"),
        webhook_id: requiredEnv("PAYPAL_WEBHOOK_ID"),
        webhook_event: event,
      }),
    },
  );
  const body = await response.json();
  if (!response.ok || body.verification_status !== "SUCCESS") {
    throw new Error("PayPal signature is invalid");
  }
}

function paypalSubscriptionId(
  eventType: string,
  resource: Record<string, any>,
): string | null {
  if (eventType.startsWith("BILLING.SUBSCRIPTION.")) {
    return typeof resource.id === "string" ? resource.id : null;
  }
  const value = resource.billing_agreement_id ??
    resource.supplementary_data?.related_ids?.subscription_id;
  return typeof value === "string" ? value : null;
}

function paypalEventType(type: string): ExternalEventType | null {
  switch (type) {
    case "BILLING.SUBSCRIPTION.ACTIVATED":
      return "purchase";
    case "PAYMENT.SALE.COMPLETED":
      return "renewal";
    case "BILLING.SUBSCRIPTION.CANCELLED":
      return "cancellation";
    case "BILLING.SUBSCRIPTION.EXPIRED":
      return "expiration";
    case "BILLING.SUBSCRIPTION.SUSPENDED":
    case "BILLING.SUBSCRIPTION.PAYMENT.FAILED":
      return "billing_issue";
    case "BILLING.SUBSCRIPTION.UPDATED":
      return "plan_change";
    default:
      return null;
  }
}

function paypalStatus(
  status: unknown,
  eventType: ExternalEventType,
): ExternalSubscriptionStatus {
  if (eventType === "cancellation") return "cancelled";
  if (eventType === "expiration") return "expired";
  switch (String(status ?? "").toUpperCase()) {
    case "ACTIVE":
      return "active";
    case "SUSPENDED":
      return "past_due";
    case "CANCELLED":
      return "cancelled";
    case "EXPIRED":
      return "expired";
    default:
      return "pending";
  }
}

async function paypalWebhook(
  request: Request,
  rawBody: string,
): Promise<boolean> {
  const event = JSON.parse(rawBody);
  await verifyPayPalWebhook(request, event);
  const type = String(event.event_type ?? "");
  const eventType = paypalEventType(type);
  if (!eventType) return false;
  const resource = objectValue(event.resource);
  const subscriptionId = paypalSubscriptionId(type, resource);
  if (!subscriptionId) {
    throw new Error("PayPal event has no subscription ID");
  }

  const response = await paypalRequest(
    `/v1/billing/subscriptions/${encodeURIComponent(subscriptionId)}`,
  );
  const subscription = await response.json();
  if (!response.ok) {
    throw new Error(`PayPal subscription lookup failed (${response.status})`);
  }
  const amount = resource.amount ?? resource.billing_info?.last_payment?.amount;
  const nextBilling = subscription.billing_info?.next_billing_time;
  let periodEnd = isoFromValue(
    nextBilling ?? subscription.billing_info?.final_payment_time,
  );
  let storedPeriodStart: string | undefined;
  if (eventType === "cancellation" && !periodEnd) {
    const { data: stored, error: storedError } = await adminClient()
      .from("subscriptions")
      .select("current_period_start, current_period_end")
      .eq("provider", "paypal")
      .eq("external_subscription_id", subscriptionId)
      .maybeSingle();
    if (storedError) throw new Error(storedError.message);
    periodEnd = isoFromValue(stored?.current_period_end);
    storedPeriodStart = isoFromValue(stored?.current_period_start);
  }
  const verified: VerifiedExternalEvent = {
    provider: "paypal",
    providerEventId: String(event.id),
    eventType,
    checkoutReference: typeof subscription.custom_id === "string"
      ? subscription.custom_id
      : undefined,
    externalSubscriptionId: subscriptionId,
    providerTransactionId: String(
      resource.id ??
        resource.billing_info?.last_payment?.transaction_id ??
        event.id,
    ),
    providerProductId: String(subscription.plan_id),
    status: paypalStatus(subscription.status, eventType),
    periodStart: storedPeriodStart ??
      isoFromValue(
        resource.time ?? subscription.start_time ?? event.create_time,
      ),
    periodEnd,
    autoRenewEnabled: !["CANCELLED", "EXPIRED"].includes(
      String(subscription.status).toUpperCase(),
    ),
    amountMinor: decimalMinor(amount?.value),
    currencyCode: typeof amount?.currency_code === "string"
      ? amount.currency_code.toUpperCase()
      : undefined,
    environment: paypalEnvironment(),
    metadata: {
      paypal_event_type: type,
      paypal_status: subscription.status,
    },
  };
  await applyVerifiedExternalEvent(adminClient(), verified);
  return true;
}

async function flutterwaveSubscriptions(
  email: string,
  providerPlanId?: string,
  transactionId?: string,
  status?: "active" | "cancelled",
): Promise<Record<string, any>[]> {
  const query = new URLSearchParams({ email });
  if (providerPlanId) query.set("plan", providerPlanId);
  if (transactionId) query.set("transaction_id", transactionId);
  if (status) query.set("status", status);
  const response = await flutterwaveRequest(
    `/v3/subscriptions?${query.toString()}`,
  );
  const body = await response.json();
  if (!response.ok || !Array.isArray(body.data)) {
    throw new Error(
      `Flutterwave subscription lookup failed (${response.status})`,
    );
  }
  return body.data.filter((item: Record<string, any>) => {
    const plan = item.plan?.id ?? item.plan;
    return !providerPlanId || String(plan) === providerPlanId;
  });
}

async function flutterwaveWebhook(
  request: Request,
  rawBody: string,
): Promise<boolean> {
  await verifyFlutterwaveSignature(
    rawBody,
    request.headers.get("flutterwave-signature"),
  );
  const webhook = JSON.parse(rawBody);
  const eventName = String(webhook.type ?? webhook.event);
  const webhookData = objectValue(webhook.data);
  const admin = adminClient();

  if (eventName === "subscription.cancelled") {
    const providerPlanId = String(webhookData.plan?.id ?? "");
    const customerEmail = String(webhookData.customer?.email ?? "");
    if (!providerPlanId || !customerEmail) {
      throw new Error("Flutterwave cancellation is incomplete");
    }
    const providerSubscriptions = await flutterwaveSubscriptions(
      customerEmail,
      providerPlanId,
      undefined,
      "cancelled",
    );
    const externalSubscriptionIds = providerSubscriptions
      .map((item) => String(item.id ?? ""))
      .filter(Boolean)
      .map((id) => `flutterwave:${id}`);
    if (externalSubscriptionIds.length === 0) {
      throw new Error("Flutterwave cancellation has no subscription ID");
    }
    const { data: existing, error: existingError } = await admin
      .from("subscriptions")
      .select(
        "id, external_subscription_id, current_period_start, current_period_end, receipt_metadata",
      )
      .eq("provider", "flutterwave")
      .eq("is_current", true)
      .in("external_subscription_id", externalSubscriptionIds)
      .maybeSingle();
    if (existingError) throw new Error(existingError.message);
    if (!existing) return false;
    const externalSubscriptionId = String(existing.external_subscription_id);
    const stableId =
      `maplov:cancel:flutterwave:${existing.id}:${existing.current_period_end}`;
    await applyVerifiedExternalEvent(admin, {
      provider: "flutterwave",
      providerEventId: stableId,
      eventType: "cancellation",
      checkoutReference: existing.receipt_metadata?.checkout_reference ??
        undefined,
      externalSubscriptionId,
      providerTransactionId: stableId,
      providerProductId: providerPlanId,
      status: "cancelled",
      periodStart: existing.current_period_start ?? undefined,
      periodEnd: existing.current_period_end ?? undefined,
      autoRenewEnabled: false,
      amountMinor: decimalMinor(webhookData.amount),
      currencyCode: typeof webhookData.currency === "string"
        ? webhookData.currency.toUpperCase()
        : undefined,
      environment: requiredEnv("FLUTTERWAVE_SECRET_KEY").includes("_TEST")
        ? "sandbox"
        : "production",
      metadata: {
        flutterwave_event_type: eventName,
        flutterwave_webhook_id: webhook.webhook_id ?? webhook.id,
      },
    });
    return true;
  }

  if (eventName !== "charge.completed") {
    return false;
  }
  const transactionId = String(webhookData.id ?? "");
  if (!transactionId) throw new Error("Flutterwave transaction ID is missing");

  const verificationResponse = await flutterwaveRequest(
    `/v3/transactions/${encodeURIComponent(transactionId)}/verify`,
  );
  const verification = await verificationResponse.json();
  const transaction = objectValue(verification.data);
  if (!verificationResponse.ok || verification.status !== "success") {
    throw new Error("Flutterwave did not verify the transaction");
  }
  const reference = String(transaction.tx_ref ?? transaction.reference ?? "");
  const { data: checkout, error: checkoutError } = await admin
    .from("external_checkout_sessions")
    .select(
      "id, checkout_reference, provider_product_id, amount_minor, currency_code, status",
    )
    .eq("provider", "flutterwave")
    .eq("checkout_reference", reference)
    .maybeSingle();
  if (checkoutError) throw new Error(checkoutError.message);

  if (
    !["successful", "succeeded"].includes(
      String(transaction.status).toLowerCase(),
    )
  ) {
    if (checkout) {
      const { error: failedCheckoutError } = await admin
        .from("external_checkout_sessions")
        .update({ status: "failed", updated_at: new Date().toISOString() })
        .eq("id", checkout.id);
      if (failedCheckoutError) throw new Error(failedCheckoutError.message);
    }
    return true;
  }

  const hintedProviderPlanId = String(
    checkout?.provider_product_id ??
      transaction.payment_plan?.id ??
      transaction.payment_plan ??
      webhookData.payment_plan?.id ??
      webhookData.payment_plan ??
      "",
  );
  const customerEmail = String(transaction.customer?.email ?? "");
  if (!customerEmail) throw new Error("Flutterwave customer email is missing");
  const subscriptions = await flutterwaveSubscriptions(
    customerEmail,
    hintedProviderPlanId || undefined,
    transactionId,
  );
  if (subscriptions.length !== 1) {
    throw new Error(
      "Flutterwave subscription could not be identified uniquely",
    );
  }
  const subscription = subscriptions[0];
  const subscriptionId = String(subscription.id ?? "");
  if (!subscriptionId) {
    throw new Error("Flutterwave subscription ID is missing");
  }
  const providerPlanId = String(
    subscription.plan?.id ?? subscription.plan ?? hintedProviderPlanId,
  );
  if (
    !providerPlanId ||
    (hintedProviderPlanId && providerPlanId !== hintedProviderPlanId)
  ) {
    throw new Error("Flutterwave payment plan is missing or inconsistent");
  }
  const externalSubscriptionId = `flutterwave:${subscriptionId}`;
  const { data: existingSubscription, error: existingError } = await admin
    .from("subscriptions")
    .select("id, tier")
    .eq("provider", "flutterwave")
    .eq("external_subscription_id", externalSubscriptionId)
    .maybeSingle();
  if (existingError) throw new Error(existingError.message);

  const expectedPlan = checkout
    ? {
      providerProductId: String(checkout.provider_product_id),
      amountMinor: Number(checkout.amount_minor),
      currencyCode: String(checkout.currency_code).toUpperCase(),
    }
    : existingSubscription
    ? await planFor(
      "flutterwave",
      existingSubscription.tier === "plus" ? "plus" : "vip",
    )
    : null;
  const paidMinor = decimalMinor(transaction.amount);
  const paidCurrency = String(transaction.currency ?? "").toUpperCase();
  if (
    !expectedPlan ||
    providerPlanId !== expectedPlan.providerProductId ||
    paidMinor !== expectedPlan.amountMinor ||
    paidCurrency !== expectedPlan.currencyCode
  ) {
    throw new Error("Flutterwave amount, currency or plan does not match");
  }
  const eventType: ExternalEventType = existingSubscription
    ? "renewal"
    : "purchase";
  const statusText = String(subscription.status ?? "").toLowerCase();
  const status: ExternalSubscriptionStatus = statusText === "active"
    ? "active"
    : statusText === "cancelled"
    ? "cancelled"
    : "pending";
  const verified: VerifiedExternalEvent = {
    provider: "flutterwave",
    providerEventId: String(
      webhook.webhook_id ??
        webhook.id ??
        `flutterwave:charge:${transactionId}`,
    ),
    eventType,
    checkoutReference: checkout?.checkout_reference ??
      (typeof subscription.tx_ref === "string"
        ? subscription.tx_ref
        : undefined),
    externalSubscriptionId,
    providerTransactionId: transactionId,
    providerProductId: providerPlanId,
    status,
    periodStart: isoFromValue(
      transaction.created_at ??
        transaction.charged_at ??
        transaction.created_datetime ??
        webhookData.created_datetime,
    ) ??
      isoFromUnix(
        transaction.created_datetime ?? webhookData.created_datetime,
      ),
    periodEnd: isoFromValue(
      subscription.next_due ?? subscription.next_due_date,
    ),
    autoRenewEnabled: statusText === "active",
    amountMinor: paidMinor,
    currencyCode: paidCurrency || undefined,
    environment: requiredEnv("FLUTTERWAVE_SECRET_KEY").includes("_TEST")
      ? "sandbox"
      : "production",
    metadata: {
      flutterwave_transaction_id: transactionId,
      flutterwave_subscription_id: subscriptionId,
      flutterwave_webhook_id: webhook.webhook_id ?? webhook.id,
    },
  };
  await applyVerifiedExternalEvent(admin, verified);
  return true;
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }
  if (!environmentEnabled("EXTERNAL_CHECKOUT_ENABLED")) {
    return json({ error: "External billing is disabled" }, 503);
  }

  const provider = new URL(request.url).searchParams.get("provider") as
    | ExternalProvider
    | null;
  if (!provider || !["stripe", "paypal", "flutterwave"].includes(provider)) {
    return json({ error: "Unsupported payment provider" }, 400);
  }

  const rawBody = await request.text();
  try {
    const processed = provider === "stripe"
      ? await stripeWebhook(request, rawBody)
      : provider === "paypal"
      ? await paypalWebhook(request, rawBody)
      : await flutterwaveWebhook(request, rawBody);
    return json({ received: true, processed });
  } catch (error) {
    console.error(`${provider} webhook failed`, error);
    const message = error instanceof Error ? error.message : "";
    const invalidSignature = message.toLowerCase().includes("signature");
    return json(
      {
        error: invalidSignature
          ? "Invalid webhook signature"
          : "Webhook failed",
      },
      invalidSignature ? 401 : 500,
    );
  }
});
