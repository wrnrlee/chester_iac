#!/usr/bin/env bash
# Fails early with a clear message if GitHub settings are missing.
# Expects GCP_WIF_PROVIDER and TF_VAR_server_passwords in the environment.
set -euo pipefail
missing=0

if [ -z "${GCP_WIF_PROVIDER:-}" ]; then
  echo "::error::Repository variable GCP_WIF_PROVIDER is not set (bootstrap output github_wif_provider)."
  missing=1
fi

if ! printf '%s' "${TF_VAR_server_passwords:-}" | jq -e 'type == "object"' >/dev/null 2>&1; then
  echo "::error::Secret VALHEIM_SERVER_PASSWORDS must be a JSON object like {\"brotherskaraminkov\": \"pass1\", \"youmadbro\": \"pass2\"}."
  exit 1
fi

for dir in stacks/servers/*/; do
  name=$(basename "$dir")
  if ! printf '%s' "$TF_VAR_server_passwords" \
       | jq -e --arg n "$name" '(.[$n] | type) == "string" and (.[$n] | length) >= 5' >/dev/null; then
    echo "::error::VALHEIM_SERVER_PASSWORDS has no password (5+ characters) for server \"${name}\"."
    missing=1
  fi
done

exit $missing
