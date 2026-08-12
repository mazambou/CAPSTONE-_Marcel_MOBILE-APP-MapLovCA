import { createClient } from 'jsr:@supabase/supabase-js@2.110.7';
import {
  DetectFacesCommand,
  IndexFacesCommand,
  SearchFacesByImageCommand,
} from 'npm:@aws-sdk/client-rekognition@3.1090.0';
import {
  collectionIdForCountry,
  deleteIndexedFace,
  deleteIndexedFaces,
  ensureCollection,
  normalizeRekognitionError,
  rekognitionClient,
} from '../_shared/rekognition_faces.ts';

type JsonRecord = Record<string, unknown>;
type AdminClient = ReturnType<typeof createClient>;
const maxImageBytes = 5 * 1024 * 1024;

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

async function acquireLock(
  admin: AdminClient,
  collectionId: string,
  ownerToken: string,
): Promise<boolean> {
  for (let attempt = 0; attempt < 40; attempt += 1) {
    const { data, error } = await admin.rpc(
      'try_acquire_face_enrollment_lock',
      {
        collection_id_value: collectionId,
        owner_token_value: ownerToken,
        lease_seconds_value: 300,
      },
    );
    if (error) throw new Error(error.message);
    if (data === true) return true;
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  return false;
}

async function releaseLock(
  admin: AdminClient,
  collectionId: string,
  ownerToken: string,
): Promise<void> {
  const { error } = await admin.rpc('release_face_enrollment_lock', {
    collection_id_value: collectionId,
    owner_token_value: ownerToken,
  });
  if (error) {
    console.error('Face migration lock release failed', {
      collectionId,
      error: error.message,
    });
  }
}

async function queueFaceCleanup(
  admin: AdminClient,
  collectionId: string,
  faceId: string,
  userId: string,
  reason: string,
): Promise<void> {
  const { error } = await admin.from('face_index_cleanup_queue').upsert({
    collection_id: collectionId,
    face_id: faceId,
    user_id: userId,
    reason,
  });
  if (error) {
    console.error('Unable to persist orphan face cleanup', {
      userId,
      collectionId,
      error: error.message,
    });
  }
}

async function processCleanupQueue(
  admin: AdminClient,
  limit: number,
): Promise<{ cleaned: number; failed: number }> {
  const { data: queued, error } = await admin
    .from('face_index_cleanup_queue')
    .select('collection_id, face_id, attempt_count')
    .order('created_at')
    .limit(limit);
  if (error) throw new Error(error.message);
  let cleaned = 0;
  let failed = 0;
  const client = rekognitionClient();
  for (const item of queued ?? []) {
    try {
      await deleteIndexedFace(client, item.collection_id, item.face_id);
      const { error: deleteError } = await admin
        .from('face_index_cleanup_queue')
        .delete()
        .eq('collection_id', item.collection_id)
        .eq('face_id', item.face_id);
      if (deleteError) throw new Error(deleteError.message);
      cleaned += 1;
    } catch (cleanupError) {
      failed += 1;
      await admin.from('face_index_cleanup_queue').update({
        attempt_count: Number(item.attempt_count ?? 0) + 1,
        last_attempt_at: new Date().toISOString(),
      }).eq('collection_id', item.collection_id).eq('face_id', item.face_id);
      console.error('Queued orphan face cleanup failed', {
        collectionId: item.collection_id,
        error: normalizeRekognitionError(cleanupError).code,
      });
    }
  }
  return { cleaned, failed };
}

async function migrateReference(
  admin: AdminClient,
  reference: { user_id: string; storage_path: string },
  duplicateThreshold: number,
): Promise<'indexed' | 'recovered' | 'conflict'> {
  const { data: profile, error: profileError } = await admin
    .from('profiles')
    .select('residence_country_id, country_code')
    .eq('id', reference.user_id)
    .maybeSingle();
  const countryCode = profile?.country_code?.trim().toUpperCase() ?? '';
  let countryId = profile?.residence_country_id as string | undefined;
  if (!countryId && /^[A-Z]{2}$/.test(countryCode)) {
    const { data: country } = await admin
      .from('countries')
      .select('id')
      .eq('iso2', countryCode)
      .maybeSingle();
    countryId = country?.id;
  }
  if (
    profileError || !countryId || !/^[A-Z]{2}$/.test(countryCode)
  ) {
    throw new Error('The reference has no normalized residence country');
  }

  const { data: file, error: downloadError } = await admin.storage
    .from('identity-selfies')
    .download(reference.storage_path);
  if (downloadError || !file) throw new Error('Reference selfie not found');
  const bytes = new Uint8Array(await file.arrayBuffer());
  if (bytes.length === 0 || bytes.length > maxImageBytes) {
    throw new Error('Reference selfie has an invalid size');
  }

  const client = rekognitionClient();
  const detection = await client.send(new DetectFacesCommand({
    Image: { Bytes: bytes },
    Attributes: ['DEFAULT'],
  }));
  if ((detection.FaceDetails ?? []).length !== 1) {
    throw new Error('Reference selfie must contain exactly one face');
  }

  const collectionId = collectionIdForCountry(countryCode);
  const externalImageId = reference.user_id;
  const ownerToken = crypto.randomUUID();
  if (!await acquireLock(admin, collectionId, ownerToken)) {
    throw new Error('The country collection is busy');
  }

  let newFaceId: string | undefined;
  try {
    const collection = await ensureCollection(client, collectionId);
    const search = await client.send(new SearchFacesByImageCommand({
      CollectionId: collectionId,
      Image: { Bytes: bytes },
      FaceMatchThreshold: duplicateThreshold,
      MaxFaces: 100,
      QualityFilter: 'HIGH',
    }));
    const matches = search.FaceMatches ?? [];
    const faceIds = matches
      .map((match) => match.Face?.FaceId)
      .filter((faceId): faceId is string => Boolean(faceId));
    const { data: mapped, error: mappingError } = faceIds.length
      ? await admin
        .from('face_references')
        .select('user_id, face_id')
        .eq('collection_id', collectionId)
        .in('face_id', faceIds)
      : { data: [], error: null };
    if (mappingError) throw new Error(mappingError.message);
    const usersByFaceId = new Map(
      (mapped ?? []).map((item) => [item.face_id, item.user_id]),
    );
    const ownMatches = matches.filter((match) => {
      const faceId = match.Face?.FaceId;
      return match.Face?.ExternalImageId === externalImageId ||
        (faceId && usersByFaceId.get(faceId) === reference.user_id);
    });
    const otherMatch = matches.find((match) => {
      const faceId = match.Face?.FaceId;
      const mappedUser = faceId ? usersByFaceId.get(faceId) : undefined;
      return mappedUser
        ? mappedUser !== reference.user_id
        : match.Face?.ExternalImageId !== externalImageId;
    });

    // An interrupted earlier run may have indexed the same ExternalImageId
    // more than once. Keep one candidate and remove all extra copies.
    const recoveredFaceId = ownMatches[0]?.Face?.FaceId;
    const extraOwnFaceIds = ownMatches.slice(recoveredFaceId ? 1 : 0)
      .map((match) => match.Face?.FaceId)
      .filter((faceId): faceId is string => Boolean(faceId));
    await deleteIndexedFaces(client, collectionId, extraOwnFaceIds);

    if (otherMatch) {
      if (recoveredFaceId) {
        await deleteIndexedFace(client, collectionId, recoveredFaceId);
      }
      console.warn('Legacy face migration found a duplicate', {
        userId: reference.user_id,
        collectionId,
        requestId: search.$metadata.requestId,
      });
      return 'conflict';
    }

    let faceId = recoveredFaceId;
    let indexRequestId: string | undefined;
    let faceModelVersion = collection.faceModelVersion;
    let result: 'indexed' | 'recovered' = 'recovered';
    if (!faceId) {
      const indexing = await client.send(new IndexFacesCommand({
        CollectionId: collectionId,
        Image: { Bytes: bytes },
        ExternalImageId: externalImageId,
        MaxFaces: 1,
        QualityFilter: 'HIGH',
        DetectionAttributes: ['DEFAULT'],
      }));
      faceId = indexing.FaceRecords?.[0]?.Face?.FaceId;
      if (!faceId) throw new Error('AWS Rekognition did not index the face');
      newFaceId = faceId;
      indexRequestId = indexing.$metadata.requestId;
      faceModelVersion = indexing.FaceModelVersion ?? faceModelVersion;
      result = 'indexed';
    }

    const { data: updated, error: updateError } = await admin
      .from('face_references')
      .update({
        country_id: countryId,
        face_id: faceId,
        collection_id: collectionId,
        external_image_id: externalImageId,
        indexed_at: new Date().toISOString(),
        index_request_id: indexRequestId ?? search.$metadata.requestId ?? null,
        face_model_version: faceModelVersion ?? null,
        updated_at: new Date().toISOString(),
      })
      .eq('user_id', reference.user_id)
      .is('face_id', null)
      .select('user_id');
    if (updateError || (updated ?? []).length !== 1) {
      if (newFaceId) {
        await deleteIndexedFace(client, collectionId, newFaceId);
        newFaceId = undefined;
      }
      throw new Error(updateError?.message ?? 'Reference was already migrated');
    }
    return result;
  } catch (error) {
    if (newFaceId) {
      try {
        await deleteIndexedFace(client, collectionId, newFaceId);
      } catch (cleanupError) {
        await queueFaceCleanup(
          admin,
          collectionId,
          newFaceId,
          reference.user_id,
          'legacy_migration_db_write_failed',
        );
        console.error('Orphan face compensation failed', {
          userId: reference.user_id,
          collectionId,
          error: normalizeRekognitionError(cleanupError).code,
        });
      }
    }
    throw error;
  } finally {
    await releaseLock(admin, collectionId, ownerToken);
  }
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') return response(405, { code: 'method_not_allowed' });
  const configuredSecret = Deno.env.get('MAPLOV_FACE_MIGRATION_SECRET') ?? '';
  const suppliedSecret = request.headers.get('X-MapLov-Migration-Secret') ?? '';
  if (
    configuredSecret.length < 32 ||
    !safeEqual(configuredSecret, suppliedSecret)
  ) return response(401, { code: 'invalid_migration_secret' });

  let payload: JsonRecord = {};
  try {
    payload = await request.json() as JsonRecord;
  } catch (_) {
    return response(400, { code: 'invalid_json' });
  }
  const requestedLimit = Number(payload.limit ?? 10);
  const limit = Number.isFinite(requestedLimit)
    ? Math.max(1, Math.min(25, Math.trunc(requestedLimit)))
    : 10;
  const thresholdValue = Number(
    Deno.env.get('REKOGNITION_DUPLICATE_ACCOUNT_THRESHOLD') ?? '98',
  );
  const duplicateThreshold = Number.isFinite(thresholdValue)
    ? Math.min(100, Math.max(95, thresholdValue))
    : 98;

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceKey) {
    return response(503, { code: 'backend_not_configured' });
  }
  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const cleanup = await processCleanupQueue(admin, limit);
  const { data: references, error } = await admin
    .from('face_references')
    .select('user_id, storage_path')
    .is('face_id', null)
    .order('enrolled_at')
    .limit(limit);
  if (error) return response(503, { code: 'migration_query_failed', message: error.message });

  let indexed = 0;
  let recovered = 0;
  let conflicts = 0;
  let failed = 0;
  for (const reference of references ?? []) {
    try {
      const result = await migrateReference(
        admin,
        reference,
        duplicateThreshold,
      );
      if (result === 'indexed') indexed += 1;
      if (result === 'recovered') recovered += 1;
      if (result === 'conflict') conflicts += 1;
    } catch (migrationError) {
      failed += 1;
      console.error('Legacy face reference migration failed', {
        userId: reference.user_id,
        error: migrationError instanceof Error
          ? migrationError.message
          : String(migrationError),
      });
    }
  }
  return response(200, {
    examined: (references ?? []).length,
    indexed,
    recovered,
    conflicts,
    failed,
    orphanFacesCleaned: cleanup.cleaned,
    orphanCleanupFailed: cleanup.failed,
    remainingMayExist: (references ?? []).length === limit,
  });
});
