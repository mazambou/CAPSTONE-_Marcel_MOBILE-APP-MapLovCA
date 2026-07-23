import { createRemoteJWKSet, jwtVerify } from 'npm:jose@6.1.0';
import {
  adminClient,
  appleEventFromTransaction,
  applyVerifiedStoreEvent,
  decodeAppleNotification,
  StoreEventType,
  verifyGoogleSubscription,
} from '../_shared/store_billing.ts';

const googleKeys = createRemoteJWKSet(
  new URL('https://www.googleapis.com/oauth2/v3/certs'),
);

function json(body: Record<string, unknown>, status = 200): Response {
  return Response.json(body, { status });
}

function decodeBase64Json(value: string): Record<string, any> {
  const normalized = value.replace(/-/g, '+').replace(/_/g, '/');
  const decoded = atob(normalized.padEnd(Math.ceil(normalized.length / 4) * 4, '='));
  return JSON.parse(decoded);
}

async function verifyGooglePush(request: Request): Promise<void> {
  const authorization = request.headers.get('Authorization') ?? '';
  if (!authorization.startsWith('Bearer ')) throw new Error('Google push token missing');
  const audience = Deno.env.get('GOOGLE_PUBSUB_AUDIENCE');
  const expectedEmail = Deno.env.get('GOOGLE_PUBSUB_SERVICE_ACCOUNT');
  if (!audience || !expectedEmail) throw new Error('Google Pub/Sub verification is not configured');
  const { payload } = await jwtVerify(authorization.substring(7), googleKeys, {
    audience,
    issuer: ['https://accounts.google.com', 'accounts.google.com'],
  });
  if (payload.email !== expectedEmail || payload.email_verified !== true) {
    throw new Error('Unexpected Google Pub/Sub sender');
  }
}

function googleEventType(notificationType: number): StoreEventType {
  switch (notificationType) {
    case 1:
    case 7:
      return 'recovery';
    case 2:
      return 'renewal';
    case 3:
      return 'cancellation';
    case 4:
      return 'purchase';
    case 5:
    case 6:
    case 10:
      return 'billing_issue';
    case 12:
      return 'refund';
    case 13:
      return 'expiration';
    default:
      return 'plan_change';
  }
}

function appleEventType(type: string, subtype?: string): StoreEventType {
  switch (type) {
    case 'SUBSCRIBED':
      return 'purchase';
    case 'DID_RENEW':
      return 'renewal';
    case 'DID_RECOVER':
      return 'recovery';
    case 'DID_FAIL_TO_RENEW':
    case 'GRACE_PERIOD_EXPIRED':
      return 'billing_issue';
    case 'EXPIRED':
      return 'expiration';
    case 'REFUND':
    case 'REVOKE':
      return 'refund';
    case 'DID_CHANGE_RENEWAL_STATUS':
      return subtype === 'AUTO_RENEW_DISABLED' ? 'cancellation' : 'recovery';
    default:
      return 'plan_change';
  }
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  try {
    const body = await request.json();
    const admin = adminClient();

    if (typeof body.signedPayload === 'string') {
      const { runtime, notification } = await decodeAppleNotification(body.signedPayload);
      if (notification.notificationType === 'TEST') return json({ received: true });
      const signedTransaction = notification.data?.signedTransactionInfo;
      if (!signedTransaction) throw new Error('Apple notification has no transaction');
      const transaction = await runtime.verifier.verifyAndDecodeTransaction(
        signedTransaction,
      ) as Record<string, any>;
      let autoRenewEnabled = true;
      if (notification.data?.signedRenewalInfo) {
        const renewal = await runtime.verifier.verifyAndDecodeRenewalInfo(
          notification.data.signedRenewalInfo,
        ) as Record<string, any>;
        autoRenewEnabled = renewal.autoRenewStatus === 1 ||
          renewal.autoRenewStatus === 'AUTO_RENEW_ENABLED';
      }
      const eventType = appleEventType(
        String(notification.notificationType),
        notification.subtype ? String(notification.subtype) : undefined,
      );
      const event = appleEventFromTransaction(
        transaction,
        runtime.environment,
        eventType,
        String(notification.notificationUUID ?? `apple:${transaction.transactionId}:${eventType}`),
        autoRenewEnabled,
      );
      await applyVerifiedStoreEvent(admin, event);
      return json({ received: true });
    }

    if (body.message?.data) {
      await verifyGooglePush(request);
      const developerNotification = decodeBase64Json(String(body.message.data));
      const subscription = developerNotification.subscriptionNotification;
      if (!subscription?.purchaseToken) {
        // Test notifications and unsupported one-time products are acknowledged.
        return json({ received: true, ignored: true });
      }
      const eventType = googleEventType(Number(subscription.notificationType));
      const event = await verifyGoogleSubscription(
        String(subscription.purchaseToken),
        subscription.subscriptionId ? String(subscription.subscriptionId) : undefined,
        eventType,
        `pubsub:${String(body.message.messageId)}`,
      );
      await applyVerifiedStoreEvent(admin, event);
      return json({ received: true });
    }

    return json({ error: 'Unsupported store notification' }, 400);
  } catch (error) {
    console.error('Store notification failed', error);
    const message = error instanceof Error ? error.message : 'Store notification failed';
    // A non-2xx response asks the store transport to retry transient failures.
    return json({ error: message }, 500);
  }
});
