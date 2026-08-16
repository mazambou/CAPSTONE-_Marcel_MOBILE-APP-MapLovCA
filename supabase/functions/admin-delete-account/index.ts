import { createClient } from 'jsr:@supabase/supabase-js@2.110.7';
import {
  deleteIndexedFace,
  rekognitionClient,
} from '../_shared/rekognition_faces.ts';

type JsonRecord = Record<string, unknown>;
type AdminClient = ReturnType<typeof createClient>;

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const storagePageSize = 1000;

function response(status: number, body: JsonRecord): Response {
  return Response.json(body, {
    status,
    headers: { 'Cache-Control': 'no-store' },
  });
}

function safeEqual(left: string, right: string): boolean {
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index += 1) {
    difference |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return difference === 0;
}

function chunks<T>(values: T[], size: number): T[][] {
  const result: T[][] = [];
  for (let index = 0; index < values.length; index += size) {
    result.push(values.slice(index, index + size));
  }
  return result;
}

async function listFilesRecursively(
  admin: AdminClient,
  bucketId: string,
  prefix: string,
): Promise<string[]> {
  const files: string[] = [];
  let offset = 0;

  while (true) {
    const { data, error } = await admin.storage.from(bucketId).list(prefix, {
      limit: storagePageSize,
      offset,
      sortBy: { column: 'name', order: 'asc' },
    });
    if (error) {
      throw new Error(`Unable to list ${bucketId}/${prefix}: ${error.message}`);
    }

    const entries = data ?? [];
    for (const entry of entries) {
      const path = prefix ? `${prefix}/${entry.name}` : entry.name;
      if (entry.id === null || entry.metadata === null) {
        files.push(...await listFilesRecursively(admin, bucketId, path));
      } else {
        files.push(path);
      }
    }
    if (entries.length < storagePageSize) break;
    offset += entries.length;
  }
  return files;
}

async function removeUserStorage(
  admin: AdminClient,
  userId: string,
): Promise<number> {
  const { data: buckets, error: bucketError } = await admin.storage.listBuckets();
  if (bucketError) {
    throw new Error(`Unable to list Storage buckets: ${bucketError.message}`);
  }

  let removed = 0;
  for (const bucket of buckets ?? []) {
    const paths = await listFilesRecursively(admin, bucket.id, userId);
    for (const batch of chunks(paths, storagePageSize)) {
      const { error } = await admin.storage.from(bucket.id).remove(batch);
      if (error) {
        throw new Error(
          `Unable to remove files from ${bucket.id}: ${error.message}`,
        );
      }
      removed += batch.length;
    }

    const remaining = await listFilesRecursively(admin, bucket.id, userId);
    if (remaining.length > 0) {
      throw new Error(`Storage cleanup is incomplete in ${bucket.id}`);
    }
  }
  return removed;
}

async function removeFaceReference(
  admin: AdminClient,
  userId: string,
): Promise<'deleted' | 'already_absent' | 'not_indexed'> {
  const { data: reference, error: referenceError } = await admin
    .from('face_references')
    .select('face_id, collection_id')
    .eq('user_id', userId)
    .maybeSingle();
  if (referenceError) {
    throw new Error(
      `Unable to load the face reference: ${referenceError.message}`,
    );
  }

  let awsResult: 'deleted' | 'already_absent' | 'not_indexed' = 'not_indexed';
  if (reference?.face_id && reference.collection_id) {
    awsResult = await deleteIndexedFace(
      rekognitionClient(),
      reference.collection_id,
      reference.face_id,
    );
  }

  const { error: deleteError } = await admin
    .from('face_references')
    .delete()
    .eq('user_id', userId);
  if (deleteError) {
    throw new Error(
      `Unable to remove the face reference row: ${deleteError.message}`,
    );
  }
  console.info('Account face reference removal completed', {
    userId,
    collectionId: reference?.collection_id ?? null,
    awsResult,
  });
  return awsResult;
}

async function eraseAccount(
  admin: AdminClient,
  userId: string,
  requestedBy: string | null,
  requestOrigin: string,
): Promise<number> {
  // Delete the indexed biometric before DB cascades erase its authoritative
  // FaceId. DeleteFaces is idempotent when the face or collection is absent.
  await removeFaceReference(admin, userId);
  let removedFiles = await removeUserStorage(admin, userId);

  const { error: purgeError } = await admin.rpc(
    'purge_account_relations_before_auth_delete',
    { user_id_value: userId },
  );
  if (purgeError) {
    throw new Error(`Unable to purge account references: ${purgeError.message}`);
  }

  const { error: authError } = await admin.auth.admin.deleteUser(userId, false);
  if (authError) {
    throw new Error(`Unable to delete Auth identity: ${authError.message}`);
  }

  // A second pass closes the small race between the first file listing and
  // deletion of the authentication identity.
  removedFiles += await removeUserStorage(admin, userId);

  if (requestedBy && requestedBy !== userId) {
    const { data: adminProfile } = await admin
      .from('profiles')
      .select('id')
      .eq('id', requestedBy)
      .maybeSingle();
    if (adminProfile) {
      await admin.from('admin_actions').insert({
        admin_id: requestedBy,
        action: 'account_deletion_completed',
        target_type: 'user',
        target_id: null,
        metadata: { mode: requestOrigin === 'admin' ? 'admin' : 'scheduled' },
      });
    }
  }
  return removedFiles;
}

async function processDue(admin: AdminClient): Promise<Response> {
  const { data: incompleteQueued, error: incompleteQueueError } = await admin
    .rpc('enqueue_stale_incomplete_registrations');
  if (incompleteQueueError) {
    console.error('Unable to queue stale incomplete registrations', {
      error: incompleteQueueError.message,
    });
  }
  const { data, error } = await admin.rpc('claim_due_account_deletions', {
    batch_size_value: 25,
  });
  if (error) {
    return response(503, {
      code: 'deletion_queue_unavailable',
      message: error.message,
    });
  }

  let processed = 0;
  let failed = 0;
  for (const item of data ?? []) {
    try {
      await eraseAccount(
        admin,
        String(item.user_id),
        item.requested_by ? String(item.requested_by) : null,
        String(item.request_origin ?? 'self'),
      );
      processed += 1;
    } catch (error) {
      failed += 1;
      console.error('Scheduled account deletion failed', {
        userId: item.user_id,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }
  return response(200, {
    incompleteQueued: Number(incompleteQueued ?? 0),
    processed,
    failed,
  });
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return response(405, {
      code: 'method_not_allowed',
      message: 'POST required',
    });
  }

  let payload: JsonRecord;
  try {
    payload = await request.json() as JsonRecord;
  } catch (_) {
    return response(400, { code: 'invalid_json', message: 'Invalid JSON body' });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !anonKey || !serviceKey) {
    return response(503, { code: 'backend_not_configured' });
  }
  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  if (payload.action === 'process_due') {
    const configuredSecret =
      Deno.env.get('MAPLOV_ACCOUNT_DELETION_CRON_SECRET') ?? '';
    const suppliedSecret =
      request.headers.get('X-MapLov-Cron-Secret') ?? '';
    if (
      configuredSecret.length < 32 ||
      !safeEqual(configuredSecret, suppliedSecret)
    ) {
      return response(401, { code: 'invalid_cron_secret' });
    }
    return await processDue(admin);
  }

  if (payload.action !== 'delete' && payload.action !== 'delete_self') {
    return response(400, {
      code: 'invalid_action',
      message: 'Unsupported action',
    });
  }

  const authHeader = request.headers.get('Authorization');
  if (!authHeader) {
    return response(401, {
      code: 'authentication_required',
      message: 'Authentication required',
    });
  }
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: { user }, error: userError } = await userClient.auth.getUser();
  if (userError || !user) {
    return response(401, {
      code: 'invalid_session',
      message: 'Invalid session',
    });
  }

  if (payload.action === 'delete_self') {
    if (payload.confirmation !== 'DELETE') {
      return response(400, {
        code: 'confirmation_required',
        message: 'Type DELETE exactly to confirm permanent deletion',
      });
    }
    const { data: currentProfile } = await admin
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .maybeSingle();
    if (currentProfile?.role === 'admin' || currentProfile?.role === 'moderator') {
      return response(409, {
        code: 'privileged_account',
        message: 'A privileged account cannot be deleted here',
      });
    }
    try {
      const removedFiles = await eraseAccount(admin, user.id, null, 'self');
      return response(200, { deleted: true, removedFiles });
    } catch (error) {
      console.error('Immediate self-deletion failed', {
        userId: user.id,
        error: error instanceof Error ? error.message : String(error),
      });
      return response(503, {
        code: 'self_deletion_failed',
        message: 'Permanent deletion could not be completed. Try again.',
      });
    }
  }

  const { data: administrator } = await admin
    .from('profiles')
    .select('role, status')
    .eq('id', user.id)
    .maybeSingle();
  if (administrator?.role !== 'admin' || administrator.status !== 'active') {
    return response(403, {
      code: 'full_admin_required',
      message: 'Full administrator access required',
    });
  }

  const userId = typeof payload.userId === 'string' ? payload.userId : '';
  const timing = payload.timing;
  const reason = typeof payload.reason === 'string'
    ? payload.reason.trim().slice(0, 1000)
    : null;
  if (!uuidPattern.test(userId)) {
    return response(400, {
      code: 'invalid_user_id',
      message: 'A valid account identifier is required',
    });
  }
  if (timing !== 'immediate' && timing !== 'scheduled') {
    return response(400, {
      code: 'invalid_timing',
      message: 'Choose immediate or scheduled deletion',
    });
  }
  if (userId === user.id) {
    return response(409, {
      code: 'cannot_delete_self',
      message: 'You cannot delete your own administrator account',
    });
  }

  const { data: target, error: targetError } = await admin
    .from('profiles')
    .select('id, role')
    .eq('id', userId)
    .maybeSingle();
  if (targetError || !target) {
    return response(404, {
      code: 'account_not_found',
      message: 'Account not found',
    });
  }
  if (target.role === 'admin' || target.role === 'moderator') {
    return response(409, {
      code: 'privileged_account',
      message: 'A privileged account cannot be deleted here',
    });
  }

  if (timing === 'scheduled') {
    const { data: scheduledFor, error } = await userClient.rpc(
      'admin_schedule_account_deletion',
      { user_id_value: userId, reason_value: reason },
    );
    if (error) {
      return response(409, {
        code: 'schedule_failed',
        message: error.message,
      });
    }
    return response(200, {
      scheduled: true,
      scheduledFor,
    });
  }

  const { error: prepareError } = await userClient.rpc(
    'admin_prepare_immediate_account_deletion',
    { user_id_value: userId, reason_value: reason },
  );
  if (prepareError) {
    return response(409, {
      code: 'deletion_preparation_failed',
      message: prepareError.message,
    });
  }

  try {
    const removedFiles = await eraseAccount(
      admin,
      userId,
      user.id,
      'admin',
    );
    return response(200, {
      deleted: true,
      removedFiles,
    });
  } catch (error) {
    console.error('Immediate account deletion failed', {
      userId,
      error: error instanceof Error ? error.message : String(error),
    });
    return response(503, {
      code: 'deletion_queued_for_retry',
      message:
        'The account is disabled and deletion will be retried automatically.',
    });
  }
});
