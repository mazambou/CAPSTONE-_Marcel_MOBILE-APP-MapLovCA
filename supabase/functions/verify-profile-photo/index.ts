import { createClient } from 'jsr:@supabase/supabase-js@2.110.7';
import {
  CompareFacesCommand,
  DetectFacesCommand,
  RekognitionClient,
} from 'npm:@aws-sdk/client-rekognition@3.1090.0';

const maxImageBytes = 5 * 1024 * 1024;

type JsonRecord = Record<string, unknown>;

class RekognitionError extends Error {
  constructor(
    message: string,
    readonly code: string,
    readonly requestId?: string,
  ) {
    super(message);
  }
}

function response(status: number, body: JsonRecord) {
  return Response.json(body, {
    status,
    headers: { 'Cache-Control': 'no-store' },
  });
}

function rekognitionClient(): RekognitionClient {
  const accessKey = Deno.env.get('AWS_ACCESS_KEY_ID');
  const secretKey = Deno.env.get('AWS_SECRET_ACCESS_KEY');
  const sessionToken = Deno.env.get('AWS_SESSION_TOKEN');
  const region = Deno.env.get('AWS_REGION') ?? 'ca-central-1';
  if (!accessKey || !secretKey) {
    throw new RekognitionError(
      'AWS Rekognition is not configured',
      'rekognition_not_configured',
    );
  }
  return new RekognitionClient({
    region,
    credentials: {
      accessKeyId: accessKey,
      secretAccessKey: secretKey,
      ...(sessionToken ? { sessionToken } : {}),
    },
  });
}

function normalizeRekognitionError(error: unknown): RekognitionError {
  if (error instanceof RekognitionError) return error;
  const value = error as {
    name?: string;
    message?: string;
    $metadata?: { requestId?: string };
  };
  return new RekognitionError(
    value.message ?? 'AWS Rekognition rejected the image',
    value.name ?? 'rekognition_error',
    value.$metadata?.requestId,
  );
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
          'country_name, residence_location_verified_at, profile_completed_at',
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
      if (profileError || !residenceCountry || !recentResidence) {
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
      let duplicate:
        | {
          userId: string;
          similarity: number;
          requestId?: string;
        }
        | undefined;
      const pageSize = 100;
      let page = 0;
      while (!duplicate) {
        const { data: references, error: referencesError } = await admin
          .from('face_references')
          .select('user_id, storage_path')
          .neq('user_id', user.id)
          .order('user_id')
          .range(page * pageSize, (page + 1) * pageSize - 1);
        if (referencesError) throw new Error(referencesError.message);

        for (const reference of references ?? []) {
          const referenceDownload = await admin.storage
            .from('identity-selfies')
            .download(reference.storage_path);
          if (referenceDownload.error || !referenceDownload.data) continue;
          const referenceBytes = new Uint8Array(
            await referenceDownload.data.arrayBuffer(),
          );
          if (
            referenceBytes.length === 0 ||
            referenceBytes.length > maxImageBytes
          ) {
            continue;
          }
          try {
            const comparison = await client.send(
              new CompareFacesCommand({
                SourceImage: { Bytes: bytes },
                TargetImage: { Bytes: referenceBytes },
                SimilarityThreshold: duplicateThreshold,
                QualityFilter: 'HIGH',
              }),
            );
            const similarity = (comparison.FaceMatches ?? []).reduce(
              (highest, match) =>
                Math.max(highest, Number(match.Similarity ?? 0)),
              0,
            );
            if (similarity >= duplicateThreshold) {
              duplicate = {
                userId: reference.user_id,
                similarity,
                requestId: comparison.$metadata.requestId,
              };
              break;
            }
          } catch (error) {
            const comparisonError = normalizeRekognitionError(error);
            if (!comparisonError.code.includes('InvalidParameterException')) {
              throw error;
            }
          }
        }
        if ((references?.length ?? 0) < pageSize) break;
        page += 1;
      }

      if (duplicate) {
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

        // The authenticated row only exists provisionally so the private
        // selfie can be uploaded. A rejected duplicate is not a MapLov
        // account and must not remain in Auth or any profile table.
        const { error: deleteUserError } = await admin.auth.admin.deleteUser(
          user.id,
        );
        if (deleteUserError) {
          // Keep the unusable provisional row hidden until the scheduled
          // cleanup retries the permanent deletion.
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
      const { error } = await admin.from('face_references').insert({
        user_id: user.id,
        storage_path: storagePath,
        provider_request_id: detection.$metadata.requestId,
        face_confidence: confidence,
        consent_version: payload.consentVersion,
        consented_at: new Date().toISOString(),
      });
      if (error) {
        await admin.storage.from('identity-selfies').remove([storagePath]);
        return response(409, { code: 'reference_enrollment_failed', message: error.message });
      }
      await admin.from('profile_photo_face_checks').insert({
        user_id: user.id,
        check_type: 'reference_selfie',
        status: 'accepted',
        similarity: confidence,
        threshold: 99,
        provider_request_id: detection.$metadata.requestId,
      });
      return response(200, { enrolled: true });
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
