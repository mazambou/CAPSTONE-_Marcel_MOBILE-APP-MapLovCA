import { createClient } from 'jsr:@supabase/supabase-js@2.110.7';
import {
  CompareFacesCommand,
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
  RekognitionError,
} from '../_shared/rekognition_faces.ts';

const maxImageBytes = 5 * 1024 * 1024;

type JsonRecord = Record<string, unknown>;

function response(status: number, body: JsonRecord) {
  return Response.json(body, {
    status,
    headers: { 'Cache-Control': 'no-store' },
  });
}

function validOwnedPath(path: unknown, userId: string): path is string {
  return typeof path === 'string' &&
    path.startsWith(`${userId}/`) &&
    !path.includes('..') &&
    /\.(jpe?g|png)$/i.test(path);
}

function mimeType(path: string): string {
  return path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
}

async function queueFaceCleanup(
  admin: ReturnType<typeof createClient>,
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

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return response(405, { code: 'method_not_allowed', message: 'POST required' });
  }
  const authHeader = request.headers.get('Authorization');
  if (!authHeader) {
    return response(401, { code: 'authentication_required' });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const admin = createClient(supabaseUrl, serviceKey);
  const { data: { user } } = await userClient.auth.getUser();
  if (!user) return response(401, { code: 'invalid_session' });

  let payload: JsonRecord;
  try {
    payload = await request.json() as JsonRecord;
  } catch (_) {
    return response(400, { code: 'invalid_json' });
  }
  const action = payload.action;

  if (action === 'status') {
    const { data, error } = await userClient.rpc('has_my_face_reference');
    if (error) return response(500, { code: 'status_failed', message: error.message });
    return response(200, { enrolled: data === true });
  }

  if (action !== 'enroll' && action !== 'verify') {
    return response(400, { code: 'invalid_action' });
  }

  const storagePath = payload.storagePath;
  if (!validOwnedPath(storagePath, user.id)) {
    return response(400, { code: 'invalid_storage_path' });
  }

  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const { count: recentChecks, error: rateLimitError } = await admin
    .from('profile_photo_face_checks')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', user.id)
    .gte('created_at', oneHourAgo);
  if (rateLimitError) {
    return response(503, { code: 'face_verification_unavailable' });
  }
  if ((recentChecks ?? 0) >= 20) {
    const bucket = action === 'enroll'
      ? 'identity-selfies'
      : 'profile-media-pending';
    await admin.storage.from(bucket).remove([storagePath]);
    return response(429, {
      code: 'face_verification_rate_limited',
      message: 'Too many verification attempts. Try again later.',
    });
  }

  if (action === 'enroll') {
    if (payload.consentVersion !== 'face-verification-v3-global-dedup') {
      await admin.storage.from('identity-selfies').remove([storagePath]);
      return response(400, { code: 'face_consent_required' });
    }
    const { data: existing } = await admin
      .from('face_references')
      .select('storage_path')
      .eq('user_id', user.id)
      .maybeSingle();
    if (existing) {
      await admin.storage.from('identity-selfies').remove([storagePath]);
      return response(409, {
        code: 'reference_already_enrolled',
        message: 'The private reference selfie is already enrolled.',
      });
    }

    const { data: file, error: downloadError } = await admin.storage
      .from('identity-selfies')
      .download(storagePath);
    if (downloadError || !file) {
      return response(404, { code: 'reference_upload_not_found' });
    }
    const bytes = new Uint8Array(await file.arrayBuffer());
    if (bytes.length === 0 || bytes.length > maxImageBytes) {
      await admin.storage.from('identity-selfies').remove([storagePath]);
      return response(422, { code: 'invalid_image_size' });
    }

    try {
      const client = rekognitionClient();
      const detection = await client.send(
        new DetectFacesCommand({
          Image: { Bytes: bytes },
          Attributes: ['DEFAULT'],
        }),
      );
      const faces = detection.FaceDetails ?? [];
      if (faces.length !== 1) {
        await admin.from('profile_photo_face_checks').insert({
          user_id: user.id,
          check_type: 'reference_selfie',
          status: 'rejected',
          similarity: 0,
          threshold: 99,
          provider_request_id: detection.$metadata.requestId,
          failure_reason: faces.length === 0
            ? 'no_face_detected'
            : 'multiple_faces_detected',
        });
        await admin.storage.from('identity-selfies').remove([storagePath]);
        return response(422, {
          code: faces.length === 0 ? 'no_face_detected' : 'multiple_faces_detected',
          message: 'The reference selfie must contain exactly one face.',
        });
      }
      const confidence = Number(faces[0].Confidence ?? 0);
      if (confidence < 99) {
        await admin.from('profile_photo_face_checks').insert({
          user_id: user.id,
          check_type: 'reference_selfie',
          status: 'rejected',
          similarity: confidence,
          threshold: 99,
          provider_request_id: detection.$metadata.requestId,
          failure_reason: 'low_face_confidence',
        });
        await admin.storage.from('identity-selfies').remove([storagePath]);
        return response(422, {
          code: 'low_face_confidence',
          message: 'Use a clear, front-facing selfie in good light.',
        });
      }
      const { data: profile, error: profileError } = await admin
        .from('profiles')
        .select(
          'country_name, country_code, residence_country_id, residence_location_verified_at, profile_completed_at',
        )
        .eq('id', user.id)
        .maybeSingle();
      if (profile?.profile_completed_at) {
        await admin.storage.from('identity-selfies').remove([storagePath]);
        return response(409, {
          code: 'reference_enrollment_closed',
          message:
            'The private reference selfie can only be created during registration.',
        });
      }
      const residenceCountry = profile?.country_name?.trim() ?? '';
      const residenceVerifiedAt = Date.parse(
        profile?.residence_location_verified_at ?? '',
      );
      const recentResidence =
        Number.isFinite(residenceVerifiedAt) &&
        residenceVerifiedAt >= Date.now() - 10 * 60 * 1000;
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
        profileError || !residenceCountry || !countryId ||
        !/^[A-Z]{2}$/.test(countryCode) || !recentResidence
      ) {
        await admin.storage.from('identity-selfies').remove([storagePath]);
        return response(422, {
          code: 'residence_verification_required',
          message:
            'Verify your current country of residence before enrolling the private selfie.',
        });
      }

      const duplicateThresholdValue = Number(
        Deno.env.get('REKOGNITION_DUPLICATE_ACCOUNT_THRESHOLD') ?? '98',
      );
      const duplicateThreshold = Number.isFinite(duplicateThresholdValue)
        ? Math.min(100, Math.max(95, duplicateThresholdValue))
        : 98;
      const collectionId = collectionIdForCountry(countryCode);
      const externalImageId = user.id;
      const lockOwner = crypto.randomUUID();
      let lockHeld = false;
      let indexedFaceId: string | undefined;
      let indexedByThisRequest = false;
      let indexRequestId: string | undefined;
      let faceModelVersion: string | undefined;
      let searchCallCount = 0;
      let indexCallCount = 0;
      let duplicate:
        | { userId?: string; similarity: number; requestId?: string }
        | undefined;

      for (let attempt = 0; attempt < 40; attempt += 1) {
        const { data: acquired, error: lockError } = await admin.rpc(
          'try_acquire_face_enrollment_lock',
          {
            collection_id_value: collectionId,
            owner_token_value: lockOwner,
            lease_seconds_value: 300,
          },
        );
        if (lockError) throw new Error(lockError.message);
        if (acquired === true) {
          lockHeld = true;
          break;
        }
        await new Promise((resolve) => setTimeout(resolve, 250));
      }
      if (!lockHeld) {
        throw new RekognitionError(
          'Face enrollment is busy. Try again shortly.',
          'face_enrollment_busy',
        );
      }

      try {
        const collection = await ensureCollection(client, collectionId);
        faceModelVersion = collection.faceModelVersion;

        const { data: renewed, error: renewError } = await admin.rpc(
          'try_acquire_face_enrollment_lock',
          {
            collection_id_value: collectionId,
            owner_token_value: lockOwner,
            lease_seconds_value: 300,
          },
        );
        if (renewError || renewed !== true) {
          throw new RekognitionError(
            'The face enrollment lock expired',
            'face_enrollment_lock_lost',
          );
        }

        searchCallCount += 1;
        const search = await client.send(
          new SearchFacesByImageCommand({
            CollectionId: collectionId,
            Image: { Bytes: bytes },
            FaceMatchThreshold: duplicateThreshold,
            MaxFaces: 100,
            QualityFilter: 'HIGH',
          }),
        );
        const matches = search.FaceMatches ?? [];
        const matchFaceIds = matches
          .map((match) => match.Face?.FaceId)
          .filter((faceId): faceId is string => Boolean(faceId));
        const { data: mappedReferences, error: mappingError } = matchFaceIds.length
          ? await admin
            .from('face_references')
            .select('user_id, face_id')
            .eq('collection_id', collectionId)
            .in('face_id', matchFaceIds)
          : { data: [], error: null };
        if (mappingError) throw new Error(mappingError.message);
        const usersByFaceId = new Map(
          (mappedReferences ?? []).map((reference) => [
            reference.face_id,
            reference.user_id,
          ]),
        );

        const otherMatch = matches.find((match) => {
          const faceId = match.Face?.FaceId;
          const mappedUser = faceId ? usersByFaceId.get(faceId) : undefined;
          return mappedUser
            ? mappedUser !== user.id
            : match.Face?.ExternalImageId !== externalImageId;
        });
        if (otherMatch) {
          const faceId = otherMatch.Face?.FaceId;
          duplicate = {
            userId: faceId ? usersByFaceId.get(faceId) : undefined,
            similarity: Number(otherMatch.Similarity ?? 0),
            requestId: search.$metadata.requestId,
          };
        } else {
          // Recover an orphan left by a prior IndexFaces success followed by a
          // failed DB write. Keep one FaceId and remove any duplicate copies.
          const ownMatches = matches.filter((match) => {
            const faceId = match.Face?.FaceId;
            return match.Face?.ExternalImageId === externalImageId ||
              (faceId && usersByFaceId.get(faceId) === user.id);
          });
          indexedFaceId = ownMatches[0]?.Face?.FaceId;
          const extraOwnFaceIds = ownMatches
            .slice(1)
            .map((match) => match.Face?.FaceId)
            .filter((faceId): faceId is string => Boolean(faceId));
          await deleteIndexedFaces(client, collectionId, extraOwnFaceIds);

          if (!indexedFaceId) {
            indexCallCount += 1;
            const indexing = await client.send(
              new IndexFacesCommand({
                CollectionId: collectionId,
                Image: { Bytes: bytes },
                ExternalImageId: externalImageId,
                MaxFaces: 1,
                QualityFilter: 'HIGH',
                DetectionAttributes: ['DEFAULT'],
              }),
            );
            indexedFaceId = indexing.FaceRecords?.[0]?.Face?.FaceId;
            indexRequestId = indexing.$metadata.requestId;
            faceModelVersion = indexing.FaceModelVersion ?? faceModelVersion;
            indexedByThisRequest = Boolean(indexedFaceId);
            if (!indexedFaceId) {
              throw new RekognitionError(
                'AWS Rekognition could not index the detected face',
                'face_not_indexed',
                indexing.$metadata.requestId,
              );
            }
          }
        }

        if (duplicate) {
          if (duplicate.userId) {
            const { error: duplicateLogError } = await admin
              .from('duplicate_account_checks')
              .insert({
                candidate_user_id: user.id,
                matched_user_id: duplicate.userId,
                residence_country: residenceCountry,
                similarity: duplicate.similarity,
                threshold: duplicateThreshold,
                provider_request_id: duplicate.requestId,
              });
            if (duplicateLogError) throw new Error(duplicateLogError.message);
          }
          await admin.from('profile_photo_face_checks').insert({
            user_id: user.id,
            check_type: 'reference_selfie',
            status: 'rejected',
            similarity: duplicate.similarity,
            threshold: duplicateThreshold,
            provider_request_id: duplicate.requestId,
            failure_reason: 'duplicate_account_detected',
          });
          await admin.storage.from('identity-selfies').remove([storagePath]);

          const { error: deleteUserError } = await admin.auth.admin.deleteUser(
            user.id,
          );
          if (deleteUserError) {
            await admin
              .from('profiles')
              .update({ status: 'suspended', is_discoverable: false })
              .eq('id', user.id);
          }
          return response(409, {
            code: 'duplicate_account_detected',
            message:
              'A MapLov account already exists for this person. Use account recovery or contact support.',
            registrationRemoved: !deleteUserError,
          });
        }

        const { error: registrationError } = await admin.rpc(
          'register_indexed_face_reference',
          {
            owner_user: user.id,
            country_id_value: countryId,
            storage_path_value: storagePath,
            face_id_value: indexedFaceId,
            collection_id_value: collectionId,
            external_image_id_value: externalImageId,
            face_confidence_value: confidence,
            consent_version_value: payload.consentVersion,
            detect_request_id_value: detection.$metadata.requestId ?? null,
            index_request_id_value: indexRequestId ?? null,
            face_model_version_value: faceModelVersion ?? null,
            lock_owner_token_value: lockOwner,
          },
        );
        if (registrationError) {
          if (indexedByThisRequest && indexedFaceId) {
            await deleteIndexedFace(client, collectionId, indexedFaceId);
            indexedByThisRequest = false;
          }
          throw new RekognitionError(
            registrationError.message,
            'reference_enrollment_failed',
          );
        }
        return response(200, { enrolled: true });
      } catch (error) {
        if (indexedByThisRequest && indexedFaceId) {
          try {
            await deleteIndexedFace(client, collectionId, indexedFaceId);
            indexedByThisRequest = false;
          } catch (cleanupError) {
            await queueFaceCleanup(
              admin,
              collectionId,
              indexedFaceId,
              user.id,
              'enrollment_db_write_failed',
            );
            console.error('Orphan face compensation failed', {
              userId: user.id,
              collectionId,
              error: normalizeRekognitionError(cleanupError).code,
            });
          }
        }
        throw error;
      } finally {
        if (lockHeld) {
          const { error: releaseError } = await admin.rpc(
            'release_face_enrollment_lock',
            {
              collection_id_value: collectionId,
              owner_token_value: lockOwner,
            },
          );
          if (releaseError) {
            console.error('Face enrollment lock release failed', {
              userId: user.id,
              collectionId,
              error: releaseError.message,
            });
          }
        }
        console.info('Face enrollment AWS call summary', {
          userId: user.id,
          countryCode,
          detectFaces: 1,
          searchFacesByImage: searchCallCount,
          indexFaces: indexCallCount,
          compareFacesDuplicateScan: 0,
        });
      }
    } catch (error) {
      await admin.storage.from('identity-selfies').remove([storagePath]);
      const awsError = normalizeRekognitionError(error);
      await admin.from('profile_photo_face_checks').insert({
        user_id: user.id,
        check_type: 'reference_selfie',
        status: 'error',
        threshold: 99,
        provider_request_id: awsError.requestId,
        failure_reason: awsError.code,
      });
      return response(502, {
        code: awsError.code,
        message: awsError.message,
        requestId: awsError.requestId,
      });
    }
  }

  const thresholdValue = Number(
    Deno.env.get('REKOGNITION_SIMILARITY_THRESHOLD') ?? '95',
  );
  const threshold = Number.isFinite(thresholdValue)
    ? Math.min(100, Math.max(80, thresholdValue))
    : 95;
  const { data: reference } = await admin
    .from('face_references')
    .select('storage_path')
    .eq('user_id', user.id)
    .maybeSingle();
  if (!reference) {
    await admin.storage.from('profile-media-pending').remove([storagePath]);
    return response(428, {
      code: 'reference_selfie_required',
      message: 'Create your private reference selfie first.',
    });
  }

  const [referenceDownload, candidateDownload] = await Promise.all([
    admin.storage.from('identity-selfies').download(reference.storage_path),
    admin.storage.from('profile-media-pending').download(storagePath),
  ]);
  if (referenceDownload.error || !referenceDownload.data) {
    await admin.storage.from('profile-media-pending').remove([storagePath]);
    return response(409, { code: 'reference_selfie_unavailable' });
  }
  if (candidateDownload.error || !candidateDownload.data) {
    return response(404, { code: 'candidate_upload_not_found' });
  }
  const referenceBytes = new Uint8Array(
    await referenceDownload.data.arrayBuffer(),
  );
  const candidateBytes = new Uint8Array(
    await candidateDownload.data.arrayBuffer(),
  );
  if (
    referenceBytes.length === 0 ||
    referenceBytes.length > maxImageBytes ||
    candidateBytes.length === 0 ||
    candidateBytes.length > maxImageBytes
  ) {
    await admin.storage.from('profile-media-pending').remove([storagePath]);
    return response(422, { code: 'invalid_image_size' });
  }

  try {
    const client = rekognitionClient();
    const candidateDetection = await client.send(
      new DetectFacesCommand({
        Image: { Bytes: candidateBytes },
        Attributes: ['DEFAULT'],
      }),
    );
    const candidateFaces = candidateDetection.FaceDetails ?? [];
    if (candidateFaces.length !== 1) {
      await admin.from('profile_photo_face_checks').insert({
        user_id: user.id,
        status: 'rejected',
        threshold,
        provider_request_id: candidateDetection.$metadata.requestId,
        failure_reason: candidateFaces.length === 0
          ? 'no_face_detected'
          : 'multiple_faces_detected',
      });
      await admin.storage.from('profile-media-pending').remove([storagePath]);
      return response(422, {
        code: candidateFaces.length === 0
          ? 'no_face_detected'
          : 'multiple_faces_detected',
        message: 'Use a profile photo containing exactly one clear face.',
      });
    }

    const comparison = await client.send(
      new CompareFacesCommand({
        SourceImage: { Bytes: referenceBytes },
        TargetImage: { Bytes: candidateBytes },
        SimilarityThreshold: threshold,
        QualityFilter: 'HIGH',
      }),
    );
    const matches = comparison.FaceMatches ?? [];
    const similarity = matches.reduce(
      (highest, match) => Math.max(highest, Number(match.Similarity ?? 0)),
      0,
    );
    if (similarity < threshold) {
      await admin.from('profile_photo_face_checks').insert({
        user_id: user.id,
        status: 'rejected',
        similarity,
        threshold,
        provider_request_id: comparison.$metadata.requestId,
        failure_reason: 'face_mismatch',
      });
      await admin.storage.from('profile-media-pending').remove([storagePath]);
      return response(422, {
        code: 'face_mismatch',
        message: 'The face does not match the private reference selfie.',
        similarity,
      });
    }

    const finalPath = storagePath;
    const { error: uploadError } = await admin.storage
      .from('profile-media')
      .upload(finalPath, candidateBytes, {
        contentType: mimeType(finalPath),
        upsert: false,
      });
    if (uploadError) throw new Error(uploadError.message);

    const { data: photoId, error: registerError } = await admin.rpc(
      'register_verified_profile_photo',
      {
        owner_user: user.id,
        storage_path_value: finalPath,
        similarity_value: similarity,
        threshold_value: threshold,
        provider_request_id_value: comparison.$metadata.requestId ?? null,
      },
    );
    if (registerError) {
      await admin.storage.from('profile-media').remove([finalPath]);
      throw new Error(registerError.message);
    }
    await admin.storage.from('profile-media-pending').remove([storagePath]);
    return response(200, { verified: true, photoId, similarity });
  } catch (error) {
    await admin.storage.from('profile-media-pending').remove([storagePath]);
    const rekognitionError = normalizeRekognitionError(error);
    if (rekognitionError.code.includes('InvalidParameterException')) {
      await admin.from('profile_photo_face_checks').insert({
        user_id: user.id,
        status: 'rejected',
        threshold,
        provider_request_id: rekognitionError.requestId,
        failure_reason: 'no_comparable_face',
      });
      return response(422, {
        code: 'no_comparable_face',
        message: 'Use a clear profile photo where your face is visible.',
      });
    }
    await admin.from('profile_photo_face_checks').insert({
      user_id: user.id,
      status: 'error',
      threshold,
      provider_request_id: rekognitionError.requestId,
      failure_reason: rekognitionError.code,
    });
    return response(502, {
      code: rekognitionError.code,
      message: rekognitionError.message,
      requestId: rekognitionError.requestId,
    });
  }
});
