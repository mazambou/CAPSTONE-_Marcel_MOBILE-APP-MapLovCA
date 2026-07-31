#!/usr/bin/env bash
set -euo pipefail

# Generates the public proof files that bind maplov.ca to the signed MapLov
# binaries. Production signing values are required because debug certificates
# and guessed Apple team identifiers would silently break verified links.
if [[ $# -ne 2 ]]; then
  echo "Usage: $0 APPLE_TEAM_ID ANDROID_PLAY_SHA256_FINGERPRINT" >&2
  exit 64
fi

apple_team_id="$1"
android_fingerprint="$(printf '%s' "$2" | tr '[:lower:]' '[:upper:]')"

if [[ ! "$apple_team_id" =~ ^[A-Z0-9]{10}$ ]]; then
  echo "APPLE_TEAM_ID must contain exactly 10 uppercase letters or digits." >&2
  exit 65
fi

fingerprint_hex="${android_fingerprint//:/}"
if [[ ! "$fingerprint_hex" =~ ^[A-F0-9]{64}$ ]]; then
  echo "The Android fingerprint must contain exactly 64 hexadecimal characters." >&2
  exit 66
fi

formatted_fingerprint=""
for ((index = 0; index < 64; index += 2)); do
  byte="${fingerprint_hex:index:2}"
  if [[ -n "$formatted_fingerprint" ]]; then
    formatted_fingerprint+=":"
  fi
  formatted_fingerprint+="$byte"
done

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_directory="$(cd "$script_directory/.." && pwd)"
association_directory="$project_directory/web/.well-known"
mkdir -p "$association_directory"

cat > "$association_directory/assetlinks.json" <<JSON
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "ca.maplov.app",
      "sha256_cert_fingerprints": ["$formatted_fingerprint"]
    }
  }
]
JSON

cat > "$association_directory/apple-app-site-association" <<JSON
{
  "applinks": {
    "details": [
      {
        "appIDs": ["$apple_team_id.ca.maplov.app"],
        "components": [
          {
            "/": "/auth/callback",
            "comment": "Supabase Auth callback for MapLov"
          }
        ]
      }
    ]
  }
}
JSON

echo "Generated:"
echo "  $association_directory/assetlinks.json"
echo "  $association_directory/apple-app-site-association"
