import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  adminClient,
  applyVerifiedStoreEvent,
  verifyAppleSubscription,
  verifyGoogleSubscription,
} from '../_shared/store_billing.ts';

function json(body: Record<string, unknown>, status = 200): Response {
  return Response.json(body, { status });
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  try {
    const authHeader = request.headers.get('Authorization');
    if (!authHeader) return json({ error: 'Authentication required' }, 401);

    const userClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return json({ error: 'Invalid session' }, 401);

    const payload = await request.json();
    const productId = String(payload.productId ?? '');
    const source = String(payload.source ?? '');
    const eventType = payload.restored === true ? 'restore' : 'purchase';
    let event;

    if (source === 'google_play') {
      const token = String(payload.serverVerificationData ?? '');
      if (!token) return json({ error: 'Google purchase token is required' }, 400);
      event = await verifyGoogleSubscription(token, productId, eventType);
    } else if (source === 'app_store') {
      const transactionId = String(payload.purchaseId ?? '');
      if (!transactionId) return json({ error: 'Apple transaction ID is required' }, 400);
      event = await verifyAppleSubscription(transactionId, productId, eventType);
    } else {
      return json({ error: 'Unsupported store source' }, 400);
    }

    const subscriptionId = await applyVerifiedStoreEvent(adminClient(), event, user.id);
    return json({
      verified: true,
      subscriptionId,
      tier: event.tier,
      status: event.status,
      periodEnd: event.periodEnd,
    });
  } catch (error) {
    console.error('Store verification failed', error);
    const message = error instanceof Error ? error.message : 'Store verification failed';
    return json({ error: message }, 422);
  }
});
