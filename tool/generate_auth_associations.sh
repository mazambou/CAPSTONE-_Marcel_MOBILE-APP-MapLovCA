#!/usr/bin/env bash
set -euo pipefail

# Generates the public proof files that bind maplov.ca to the signed MapLov
# binaries. Production signing values are required because debug certificates
# and guessed Apple team identifiers would silently break verified links.
if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 ANDROID_PLAY_SHA256_FINGERPRINT [APPLE_TEAM_ID]" >&2
  exit 64
fi

android_fingerprint="$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')"
apple_team_id="${2:-}"

if [[ -n "$apple_team_id" && ! "$apple_team_id" =~ ^[A-Z0-9]{10}$ ]]; then
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

if [[ -n "$apple_team_id" ]]; then
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
fi

echo "Generated:"
echo "  $association_directory/assetlinks.json"
if [[ -n "$apple_team_id" ]]; then
  echo "  $association_directory/apple-app-site-association"
fi
