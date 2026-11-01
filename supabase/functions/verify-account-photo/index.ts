import { createClient } from 'jsr:@supabase/supabase-js@2.110.7';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Max-Age': '86400',
};

function reply(status: number, code: string, details?: Record<string, unknown>) {
  return Response.json({ code, ...details }, {
    status,
    headers: { ...corsHeaders, 'Cache-Control': 'no-store' },
  });
}

function ownedImagePath(value: unknown, userId: string): value is string {
  return typeof value === 'string' &&
    value.startsWith(`${userId}/`) &&
    !value.includes('..') &&
    /^[0-9a-f-]+\.(jpe?g|png)$/i.test(value.slice(userId.length + 1));
}

function validImage(bytes: Uint8Array, path: string): boolean {
  if (bytes.length === 0 || bytes.length > 5 * 1024 * 1024) return false;
  if (/\.png$/i.test(path)) {
    return bytes.length >= 8 &&
      [137, 80, 78, 71, 13, 10, 26, 10].every((value, index) =>
        bytes[index] === value
      );
  }
  return bytes.length >= 4 && bytes[0] === 255 && bytes[1] === 216 &&
    bytes[bytes.length - 2] === 255 && bytes[bytes.length - 1] === 217;
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (request.method !== 'POST') return reply(405, 'method_not_allowed');

  const authorization = request.headers.get('Authorization');
  if (!authorization) return reply(401, 'authentication_required');

  const userClient = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authorization } } },
  );
  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );
  const { data: { user }, error: userError } = await userClient.auth.getUser();
  if (userError || !user) return reply(401, 'invalid_session');

  let path: unknown;
  try {
    path = (await request.json() as { storagePath?: unknown }).storagePath;
  } catch (_) {
    return reply(400, 'invalid_json');
  }
  if (!ownedImagePath(path, user.id)) {
    return reply(400, 'invalid_storage_path');
  }

  const { data: accountReady, error: statusError } = await userClient.rpc(
    'has_my_account_verification',
  );
  if (statusError) return reply(503, 'account_verification_unavailable');
  if (accountReady !== true) {
    await admin.storage.from('profile-media-pending').remove([path]);
    return reply(428, 'account_verification_required', {
      message: 'Verify your email or complete the SMS registration fallback, then verify your phone and residence before adding a photo.',
    });
  }

  const { data: file, error: downloadError } = await admin.storage
    .from('profile-media-pending').download(path);
  if (downloadError || !file) return reply(404, 'photo_upload_not_found');
  const bytes = new Uint8Array(await file.arrayBuffer());
  if (!validImage(bytes, path)) {
    await admin.storage.from('profile-media-pending').remove([path]);
    return reply(422, 'invalid_image', {
      message: 'Upload a valid JPEG or PNG image of at most 5 MB.',
    });
  }

  const contentType = /\.png$/i.test(path) ? 'image/png' : 'image/jpeg';
  const { error: uploadError } = await admin.storage.from('profile-media')
    .upload(path, bytes, { contentType, upsert: false });
  if (uploadError) return reply(503, 'photo_storage_failed');

  const { data: photoId, error: registerError } = await admin.rpc(
    'register_account_checked_profile_photo',
    { owner_user: user.id, storage_path_value: path },
  );
  if (registerError) {
    console.error('Account photo registration failed', {
      userId: user.id,
      code: registerError.code,
    });
    await admin.storage.from('profile-media').remove([path]);
    await admin.storage.from('profile-media-pending').remove([path]);
    return reply(422, 'account_photo_registration_failed', {
      message: 'Verify your email or complete the SMS registration fallback, then verify your phone and residence.',
    });
  }

  await admin.storage.from('profile-media-pending').remove([path]);
  return reply(200, 'photo_added', {
    photoId,
    faceVerified: false,
    verificationMethod: 'account_checks',
  });
});
