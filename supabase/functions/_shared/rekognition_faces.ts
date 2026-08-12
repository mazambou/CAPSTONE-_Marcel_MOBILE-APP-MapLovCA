import {
  CreateCollectionCommand,
  DeleteFacesCommand,
  DescribeCollectionCommand,
  RekognitionClient,
} from 'npm:@aws-sdk/client-rekognition@3.1090.0';

export class RekognitionError extends Error {
  constructor(
    message: string,
    readonly code: string,
    readonly requestId?: string,
  ) {
    super(message);
  }
}

export function rekognitionClient(): RekognitionClient {
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

export function normalizeRekognitionError(error: unknown): RekognitionError {
  if (error instanceof RekognitionError) return error;
  const value = error as {
    name?: string;
    message?: string;
    $metadata?: { requestId?: string };
  };
  return new RekognitionError(
    value.message ?? 'AWS Rekognition rejected the operation',
    value.name ?? 'rekognition_error',
    value.$metadata?.requestId,
  );
}

function isAwsError(error: unknown, name: string): boolean {
  return normalizeRekognitionError(error).code.includes(name);
}

export function collectionIdForCountry(countryCode: string): string {
  const normalizedCountry = countryCode.trim().toUpperCase();
  if (!/^[A-Z]{2}$/.test(normalizedCountry)) {
    throw new RekognitionError(
      'A valid ISO country code is required',
      'invalid_country_code',
    );
  }
  const configuredPrefix =
    Deno.env.get('REKOGNITION_COLLECTION_PREFIX') ?? 'maplov-faces';
  const safePrefix = configuredPrefix
    .trim()
    .replace(/[^A-Za-z0-9_.-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 252);
  if (!safePrefix) {
    throw new RekognitionError(
      'The Rekognition collection prefix is invalid',
      'invalid_collection_prefix',
    );
  }
  return `${safePrefix}-${normalizedCountry}`;
}

export async function ensureCollection(
  client: RekognitionClient,
  collectionId: string,
): Promise<{ faceModelVersion?: string; created: boolean }> {
  try {
    const description = await client.send(
      new DescribeCollectionCommand({ CollectionId: collectionId }),
    );
    return {
      faceModelVersion: description.FaceModelVersion,
      created: false,
    };
  } catch (error) {
    if (!isAwsError(error, 'ResourceNotFoundException')) throw error;
  }

  try {
    const creation = await client.send(
      new CreateCollectionCommand({ CollectionId: collectionId }),
    );
    return {
      faceModelVersion: creation.FaceModelVersion,
      created: true,
    };
  } catch (error) {
    // CreateCollection is idempotent under concurrent first registrations:
    // the loser observes the already-created collection and continues.
    if (!isAwsError(error, 'ResourceAlreadyExistsException')) throw error;
    const description = await client.send(
      new DescribeCollectionCommand({ CollectionId: collectionId }),
    );
    return {
      faceModelVersion: description.FaceModelVersion,
      created: false,
    };
  }
}

export async function deleteIndexedFace(
  client: RekognitionClient,
  collectionId: string,
  faceId: string,
): Promise<'deleted' | 'already_absent'> {
  try {
    const deletion = await client.send(
      new DeleteFacesCommand({
        CollectionId: collectionId,
        FaceIds: [faceId],
      }),
    );
    return deletion.DeletedFaces?.includes(faceId)
      ? 'deleted'
      : 'already_absent';
  } catch (error) {
    if (
      isAwsError(error, 'ResourceNotFoundException') ||
      isAwsError(error, 'InvalidParameterException')
    ) {
      return 'already_absent';
    }
    throw error;
  }
}

export async function deleteIndexedFaces(
  client: RekognitionClient,
  collectionId: string,
  faceIds: string[],
): Promise<void> {
  const uniqueFaceIds = [...new Set(faceIds.filter(Boolean))];
  if (uniqueFaceIds.length === 0) return;
  try {
    await client.send(
      new DeleteFacesCommand({
        CollectionId: collectionId,
        FaceIds: uniqueFaceIds,
      }),
    );
  } catch (error) {
    if (
      isAwsError(error, 'ResourceNotFoundException') ||
      isAwsError(error, 'InvalidParameterException')
    ) return;
    throw error;
  }
}
