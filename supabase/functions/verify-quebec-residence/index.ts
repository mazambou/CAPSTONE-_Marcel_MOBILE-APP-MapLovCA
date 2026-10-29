import { createClient } from 'jsr:@supabase/supabase-js@2.110.7';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Max-Age': '86400',
};

function reply(status: number, body: Record<string, unknown>) {
  return Response.json(body, {
    status,
    headers: { ...corsHeaders, 'Cache-Control': 'no-store' },
  });
}

function normalizedRegion(value: string): string {
  return value.normalize('NFD').replace(/\p{Diacritic}/gu, '')
    .trim().toLowerCase();
}

function isQuebecRegion(value: string): boolean {
  const region = normalizedRegion(value);
  return region === 'quebec' || region === 'province of quebec';
}

function field(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (request.method !== 'POST') {
    return reply(405, { code: 'method_not_allowed' });
  }
  const authorization = request.headers.get('Authorization');
  if (!authorization) return reply(401, { code: 'authentication_required' });

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const userClient = createClient(
    supabaseUrl,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authorization } } },
  );
  const admin = createClient(
    supabaseUrl,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );
  const { data: { user }, error: authError } = await userClient.auth.getUser();
  if (authError || !user) return reply(401, { code: 'invalid_session' });

  const { data: context, error: contextError } = await admin.rpc(
    'get_quebec_residence_check_context',
    { owner_user: user.id },
  );
  if (contextError || !context || typeof context !== 'object') {
    return reply(428, { code: 'device_location_required' });
  }
  const location = context as Record<string, unknown>;
  if (typeof location.cachedEligible === 'boolean') {
    return reply(200, { eligible: location.cachedEligible });
  }
  const latitude = Number(location.latitude);
  const longitude = Number(location.longitude);
  const updatedAt = field(location.updatedAt);
  const accurate = location.accuracyMeters == null ||
    Number(location.accuracyMeters) <= 1000;
  if (
    !Number.isFinite(latitude) || !Number.isFinite(longitude) ||
    !updatedAt || !accurate ||
    !Number.isFinite(Date.parse(updatedAt)) ||
    Date.parse(updatedAt) < Date.now() - 10 * 60 * 1000
  ) {
    return reply(428, { code: 'recent_device_location_required' });
  }

  const query = new URLSearchParams({
    format: 'jsonv2',
    lat: latitude.toFixed(5),
    lon: longitude.toFixed(5),
    zoom: '10',
    addressdetails: '1',
    'accept-language': 'en',
  });
  let countryCode: string;
  let region: string;
  try {
    const geocode = await fetch(
      `https://nominatim.openstreetmap.org/reverse?${query}`,
      {
        headers: {
          Accept: 'application/json',
          'User-Agent': 'MapLov/1.0 (https://maplov.ca)',
        },
        signal: AbortSignal.timeout(8000),
      },
    );
    if (!geocode.ok) throw new Error('Reverse geocoding unavailable');
    const result = await geocode.json();
    const address = result?.address ?? {};
    countryCode = field(address.country_code).toUpperCase();
    region = field(
      address.state ?? address.province ?? address.region ??
        address.state_district,
    );
  } catch (error) {
    console.error('Québec residence check failed', {
      userId: user.id,
      error: error instanceof Error ? error.name : 'unknown',
    });
    return reply(503, { code: 'residence_check_unavailable' });
  }

  const eligible = countryCode === 'CA' && isQuebecRegion(region);
  const { error: recordError } = await admin.rpc(
    'record_quebec_residence_check',
    {
      owner_user: user.id,
      location_updated_at_value: updatedAt,
      eligible_value: eligible,
      country_code_value: countryCode || 'unknown',
      region_value: region || 'unknown',
    },
  );
  if (recordError) {
    return reply(409, { code: 'device_location_changed' });
  }
  return reply(200, { eligible });
});
