# Face verification operations

MapLov stores one AWS Rekognition collection per ISO residence country. The
collection ID is `${REKOGNITION_COLLECTION_PREFIX}-${ISO2}`; the default prefix
is `maplov-faces` (for example, `maplov-faces-CA`).

The Edge Functions require these secrets:

- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and optionally
  `AWS_SESSION_TOKEN`;
- `AWS_REGION` (defaults to `ca-central-1`);
- `REKOGNITION_COLLECTION_PREFIX` (defaults to `maplov-faces`);
- `REKOGNITION_DUPLICATE_ACCOUNT_THRESHOLD` (defaults to `98`);
- `MAPLOV_FACE_MIGRATION_SECRET`, a random value of at least 32 characters.

The AWS identity needs only the Rekognition actions used by the backend:
`DetectFaces`, `DescribeCollection`, `CreateCollection`,
`SearchFacesByImage`, `IndexFaces`, `CompareFaces`, and `DeleteFaces`.

## Existing-reference migration

Deploy `migrate-face-references`, then invoke it in small repeatable batches:

```bash
curl -sS -X POST \
  -H "Content-Type: application/json" \
  -H "X-MapLov-Migration-Secret: $MAPLOV_FACE_MIGRATION_SECRET" \
  -d '{"limit":10}' \
  "https://PROJECT_REF.supabase.co/functions/v1/migrate-face-references"
```

Repeat until `examined` is `0`. Rows with a non-null `face_id` are skipped.
Before indexing a legacy reference, the worker searches once for a prior face
with the server-derived `ExternalImageId`. This lets an interrupted run adopt
its prior `FaceId`; extra copies are deleted. A match belonging to another
reference is reported as a conflict and is not indexed automatically.

The same endpoint drains `face_index_cleanup_queue`. That server-only queue
records an AWS face whenever compensating `DeleteFaces` fails after a database
write failure.
