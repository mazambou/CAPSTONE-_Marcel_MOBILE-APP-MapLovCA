import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { Buffer } from 'node:buffer';
import {
  AppStoreServerAPIClient,
  Environment,
  SignedDataVerifier,
} from 'npm:@apple/app-store-server-library@3.1.0';

export type StoreProvider = 'apple' | 'google';
export type StoreEventType =
  | 'purchase'
  | 'restore'
  | 'renewal'
  | 'cancellation'
  | 'expiration'
  | 'refund'
  | 'billing_issue'
  | 'recovery'
  | 'plan_change';

export type VerifiedStoreEvent = {
  provider: StoreProvider;
  providerEventId: string;
  eventType: StoreEventType;
  externalSubscriptionId: string;
  providerTransactionId: string;
  originalTransactionId?: string;
  productId: string;
  tier: 'plus' | 'vip';
  status: 'pending' | 'active' | 'past_due' | 'cancelled' | 'expired' | 'refunded';
  periodStart?: string;
  periodEnd?: string;
  autoRenewEnabled: boolean;
  amountMinor?: number;
  currencyCode?: string;
  environment?: string;
  metadata: Record<string, unknown>;
};

const productTiers: Record<string, 'plus' | 'vip'> = {
  maplov_plus_monthly: 'plus',
  maplov_elite_monthly: 'vip',
  maplov_vip_monthly: 'vip',
};

export function tierForProduct(productId: string): 'plus' | 'vip' {
  const tier = productTiers[productId];
  if (!tier) throw new Error(`Unknown MapLov subscription product: ${productId}`);
  return tier;
}

export function adminClient(): SupabaseClient {
  return createClient(
    requiredEnv('SUPABASE_URL'),
    requiredEnv('SUPABASE_SERVICE_ROLE_KEY'),
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
}

export async function applyVerifiedStoreEvent(
  admin: SupabaseClient,
  event: VerifiedStoreEvent,
  userId?: string,
): Promise<string> {
  const { data, error } = await admin.rpc('apply_store_subscription_event', {
    user_id_value: userId ?? null,
    provider_value: event.provider,
    provider_event_id_value: event.providerEventId,
    event_type_value: event.eventType,
    external_subscription_id_value: event.externalSubscriptionId,
    provider_transaction_id_value: event.providerTransactionId,
    original_transaction_id_value: event.originalTransactionId ?? null,
    product_id_value: event.productId,
    tier_value: event.tier,
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

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`${name} is not configured`);
  return value;
}

function toBase64Url(value: Uint8Array | string): string {
  const bytes = typeof value === 'string' ? new TextEncoder().encode(value) : value;
  return Buffer.from(bytes).toString('base64url');
}

function pemToBytes(pem: string): Uint8Array {
  const encoded = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\\n/g, '')
    .replace(/\s/g, '');
  return Uint8Array.from(Buffer.from(encoded, 'base64'));
}

let googleAccessToken: { value: string; expiresAt: number } | undefined;

async function getGoogleAccessToken(): Promise<string> {
  if (googleAccessToken && googleAccessToken.expiresAt > Date.now() + 60_000) {
    return googleAccessToken.value;
  }
  const credentials = JSON.parse(requiredEnv('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON'));
  const now = Math.floor(Date.now() / 1000);
  const header = toBase64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = toBase64Url(JSON.stringify({
    iss: credentials.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToBytes(credentials.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );
  const assertion = `${unsigned}.${toBase64Url(new Uint8Array(signature))}`;
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!response.ok) throw new Error(`Google OAuth failed (${response.status})`);
  const body = await response.json();
  googleAccessToken = {
    value: body.access_token,
    expiresAt: Date.now() + Number(body.expires_in ?? 3600) * 1000,
  };
  return googleAccessToken.value;
}

async function googlePublisherRequest(path: string, init?: RequestInit): Promise<Response> {
  const token = await getGoogleAccessToken();
  return fetch(`https://androidpublisher.googleapis.com${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      ...(init?.headers ?? {}),
    },
  });
}

function googleStatus(state: string, expiresAt?: string): VerifiedStoreEvent['status'] {
  switch (state) {
    case 'SUBSCRIPTION_STATE_ACTIVE':
    case 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD':
      return 'active';
    case 'SUBSCRIPTION_STATE_CANCELED':
      return !expiresAt || Date.parse(expiresAt) > Date.now() ? 'cancelled' : 'expired';
    case 'SUBSCRIPTION_STATE_EXPIRED':
      return 'expired';
    case 'SUBSCRIPTION_STATE_ON_HOLD':
    case 'SUBSCRIPTION_STATE_PAUSED':
      return 'past_due';
    default:
      return 'pending';
  }
}

export async function verifyGoogleSubscription(
  purchaseToken: string,
  requestedProductId?: string,
  eventType: StoreEventType = 'purchase',
  providerEventId?: string,
): Promise<VerifiedStoreEvent> {
  const packageName = Deno.env.get('GOOGLE_PLAY_PACKAGE_NAME') ?? 'ca.maplov.app';
  const path = `/androidpublisher/v3/applications/${encodeURIComponent(packageName)}` +
    `/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`;
  const response = await googlePublisherRequest(path);
  if (!response.ok) throw new Error(`Google Play rejected the purchase (${response.status})`);
  const purchase = await response.json();
  const lineItem = purchase.lineItems?.find(
    (item: Record<string, unknown>) => !requestedProductId || item.productId === requestedProductId,
  ) ?? purchase.lineItems?.[0];
  if (!lineItem?.productId || !lineItem?.expiryTime) {
    throw new Error('Google Play returned no matching subscription line item');
  }
  if (requestedProductId && lineItem.productId !== requestedProductId) {
    throw new Error('Google Play product does not match the requested product');
  }
  const status = googleStatus(purchase.subscriptionState, lineItem.expiryTime);
  const autoRenewEnabled = lineItem.autoRenewingPlan?.autoRenewEnabled === true;
  const transactionId = lineItem.latestSuccessfulOrderId ?? purchase.latestOrderId ?? purchaseToken;

  if (purchase.acknowledgementState === 'ACKNOWLEDGEMENT_STATE_PENDING' && status === 'active') {
    const acknowledgePath = `/androidpublisher/v3/applications/${encodeURIComponent(packageName)}` +
      `/purchases/subscriptions/${encodeURIComponent(lineItem.productId)}` +
      `/tokens/${encodeURIComponent(purchaseToken)}:acknowledge`;
    const acknowledge = await googlePublisherRequest(acknowledgePath, {
      method: 'POST',
      body: JSON.stringify({}),
    });
    if (!acknowledge.ok) {
      throw new Error(`Google Play acknowledgement failed (${acknowledge.status})`);
    }
  }

  return {
    provider: 'google',
    providerEventId: providerEventId ?? `client:${eventType}:${transactionId}`,
    eventType,
    externalSubscriptionId: purchaseToken,
    providerTransactionId: transactionId,
    originalTransactionId: purchase.linkedPurchaseToken ?? purchaseToken,
    productId: lineItem.productId,
    tier: tierForProduct(lineItem.productId),
    status,
    periodStart: purchase.startTime,
    periodEnd: lineItem.expiryTime,
    autoRenewEnabled,
    environment: purchase.testPurchase ? 'sandbox' : 'production',
    metadata: {
      packageName,
      purchaseToken,
      linkedPurchaseToken: purchase.linkedPurchaseToken,
      subscriptionState: purchase.subscriptionState,
      acknowledgementState: purchase.acknowledgementState,
    },
  };
}

type AppleRuntime = {
  client: AppStoreServerAPIClient;
  verifier: SignedDataVerifier;
  environment: string;
};

function appleRuntime(environment: 'production' | 'sandbox'): AppleRuntime {
  const bundleId = Deno.env.get('APPLE_BUNDLE_ID') ?? 'ca.maplov.app';
  const rootCertificates = JSON.parse(requiredEnv('APPLE_ROOT_CERTIFICATES_BASE64'))
    .map((value: string) => Buffer.from(value, 'base64'));
  const production = environment === 'production';
  const appAppleIdText = Deno.env.get('APPLE_APP_ID');
  const appAppleId = production && appAppleIdText ? Number(appAppleIdText) : undefined;
  const selectedEnvironment = production ? Environment.PRODUCTION : Environment.SANDBOX;
  return {
    client: new AppStoreServerAPIClient(
      requiredEnv('APPLE_IAP_PRIVATE_KEY').replace(/\\n/g, '\n'),
      requiredEnv('APPLE_IAP_KEY_ID'),
      requiredEnv('APPLE_IAP_ISSUER_ID'),
      bundleId,
      selectedEnvironment,
    ),
    verifier: new SignedDataVerifier(
      rootCertificates,
      true,
      selectedEnvironment,
      bundleId,
      appAppleId,
    ),
    environment,
  };
}

export async function decodeAppleNotification(signedPayload: string): Promise<{
  runtime: AppleRuntime;
  notification: Record<string, any>;
}> {
  let lastError: unknown;
  for (const environment of ['production', 'sandbox'] as const) {
    try {
      const runtime = appleRuntime(environment);
      const notification = await runtime.verifier.verifyAndDecodeNotification(signedPayload);
      return { runtime, notification: notification as Record<string, any> };
    } catch (error) {
      lastError = error;
    }
  }
  throw new Error(`Apple notification signature is invalid: ${lastError}`);
}

function appleDate(value: unknown): string | undefined {
  if (typeof value !== 'number' && typeof value !== 'string') return undefined;
  const numeric = Number(value);
  const date = Number.isFinite(numeric) ? new Date(numeric) : new Date(String(value));
  return Number.isNaN(date.getTime()) ? undefined : date.toISOString();
}

export function appleEventFromTransaction(
  transaction: Record<string, any>,
  environment: string,
  eventType: StoreEventType,
  providerEventId: string,
  autoRenewEnabled = true,
): VerifiedStoreEvent {
  if (!transaction.transactionId || !transaction.originalTransactionId || !transaction.productId) {
    throw new Error('Apple returned incomplete transaction data');
  }
  const periodEnd = appleDate(transaction.expiresDate);
  const revoked = transaction.revocationDate != null;
  const status: VerifiedStoreEvent['status'] = revoked
    ? 'refunded'
    : periodEnd && Date.parse(periodEnd) <= Date.now()
    ? 'expired'
    : eventType === 'cancellation'
    ? 'cancelled'
    : 'active';
  return {
    provider: 'apple',
    providerEventId,
    eventType: revoked ? 'refund' : eventType,
    externalSubscriptionId: transaction.originalTransactionId,
    providerTransactionId: transaction.transactionId,
    originalTransactionId: transaction.originalTransactionId,
    productId: transaction.productId,
    tier: tierForProduct(transaction.productId),
    status,
    periodStart: appleDate(transaction.purchaseDate),
    periodEnd,
    autoRenewEnabled: revoked ? false : autoRenewEnabled,
    amountMinor: typeof transaction.price === 'number'
      ? Math.round(transaction.price / 10)
      : undefined,
    currencyCode: transaction.currency,
    environment,
    metadata: {
      bundleId: transaction.bundleId,
      appAccountToken: transaction.appAccountToken,
      transactionReason: transaction.transactionReason,
      revocationReason: transaction.revocationReason,
    },
  };
}

export async function verifyAppleSubscription(
  transactionId: string,
  requestedProductId: string,
  eventType: StoreEventType = 'purchase',
): Promise<VerifiedStoreEvent> {
  let lastError: unknown;
  for (const environment of ['production', 'sandbox'] as const) {
    try {
      const runtime = appleRuntime(environment);
      const response = await runtime.client.getTransactionInfo(transactionId);
      const transaction = await runtime.verifier.verifyAndDecodeTransaction(
        response.signedTransactionInfo,
      ) as Record<string, any>;
      if (transaction.productId !== requestedProductId) {
        throw new Error('Apple product does not match the requested product');
      }
      return appleEventFromTransaction(
        transaction,
        environment,
        eventType,
        `client:${eventType}:${transaction.transactionId}`,
      );
    } catch (error) {
      lastError = error;
    }
  }
  throw new Error(`Apple rejected the transaction: ${lastError}`);
}
