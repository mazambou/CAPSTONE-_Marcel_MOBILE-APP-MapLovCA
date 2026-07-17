import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const productTiers: Record<string, 'plus' | 'elite' | 'vip'> = {
  maplov_plus_monthly: 'plus',
  maplov_elite_monthly: 'vip',
  maplov_vip_monthly: 'vip',
};

Deno.serve(async (request) => {
  const authHeader = request.headers.get('Authorization');
  if (!authHeader) return new Response('Authentication required', { status: 401 });

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const verifierUrl = Deno.env.get('STORE_VERIFICATION_URL');
  const verifierSecret = Deno.env.get('STORE_VERIFICATION_SECRET');
  if (!verifierUrl || !verifierSecret) {
    return new Response('Store verification is not configured', { status: 503 });
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user } } = await userClient.auth.getUser();
  if (!user) return new Response('Invalid session', { status: 401 });

  const payload = await request.json();
  const tier = productTiers[payload.productId];
  if (!tier || !payload.serverVerificationData || !payload.source) {
    return new Response('Invalid purchase payload', { status: 400 });
  }

  // STORE_VERIFICATION_URL must validate the signed App Store transaction or
  // Google Play purchase token directly with the relevant store API.
  const verification = await fetch(verifierUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${verifierSecret}`,
    },
    body: JSON.stringify({ ...payload, userId: user.id }),
  });
  if (!verification.ok) return new Response('Purchase rejected by store', { status: 422 });
  const verified = await verification.json();
  if (verified.valid !== true) return new Response('Invalid purchase', { status: 422 });

  const admin = createClient(supabaseUrl, serviceKey);
  await admin.from('subscriptions').update({ is_current: false }).eq('user_id', user.id).eq('is_current', true);
  const { error } = await admin.from('subscriptions').insert({
    user_id: user.id,
    tier,
    provider: payload.source === 'app_store' ? 'apple' : 'google',
    external_subscription_id: verified.subscriptionId ?? payload.purchaseId,
    status: 'active',
    current_period_start: verified.periodStart,
    current_period_end: verified.periodEnd,
    is_current: true,
    receipt_metadata: { productId: payload.productId, environment: verified.environment },
  });
  if (error) return new Response(error.message, { status: 500 });
  return Response.json({ verified: true, tier });
});
