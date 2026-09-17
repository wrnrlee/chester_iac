#!/usr/bin/env bash
# Fails early, with a specific reason, if GitHub settings are missing or
# malformed. Never prints the secret itself - only its length and shape.
# Expects GCP_WIF_PROVIDER and TF_VAR_server_passwords in the environment.
set -uo pipefail
missing=0

if [ -z "${GCP_WIF_PROVIDER:-}" ]; then
  echo "::error::Repository variable GCP_WIF_PROVIDER is not set (bootstrap output github_wif_provider)."
  missing=1
fi

raw="${TF_VAR_server_passwords:-}"

if [ -z "$raw" ]; then
  echo "::error::Secret VALHEIM_SERVER_PASSWORDS is empty or not visible to this job."
  echo "Check that: (1) it exists under Settings -> Secrets and variables -> Actions;"
  echo "(2) it is spelled exactly VALHEIM_SERVER_PASSWORDS;"
  echo "(3) it is a *repository* secret - an Environment secret is not visible to this job,"
  echo "    and an Organization secret may not be shared with this repository;"
  echo "(4) this run is not from a fork (forks get no secrets)."
  exit 1
fi

# Tolerate stray whitespace / CR from pasting.
trimmed=$(printf '%s' "$raw" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

if ! printf '%s' "$trimmed" | jq -e 'type == "object"' >/dev/null 2>/tmp/jq.err; then
  echo "::error::Secret VALHEIM_SERVER_PASSWORDS must be a JSON object like {\"brotherskaraminkov\": \"pass1\", \"youmadbro\": \"pass2\"}."
  echo "The value is ${#trimmed} characters long."
  case "$trimmed" in
    "{"*) echo "It starts with '{'." ;;
    *)    echo "It does NOT start with '{' - looks like a plain value rather than JSON." ;;
  esac
  case "$trimmed" in
    *"}") echo "It ends with '}'." ;;
    *)    echo "It does NOT end with '}' - it may be truncated." ;;
  esac
  if printf '%s' "$trimmed" | LC_ALL=C grep -qP '[\xe2\x80\x98\x99\x9c\x9d]' 2>/dev/null; then
    echo "It contains curly/smart quotes - retype the quotes as plain \" characters."
  fi
  echo "jq said:"; sed 's/^/  /' /tmp/jq.err
  exit 1
fi

for dir in stacks/servers/*/; do
  name=$(basename "$dir")
  if ! printf '%s' "$trimmed" \
       | jq -e --arg n "$name" '(.[$n] | type) == "string" and (.[$n] | length) >= 5' >/dev/null 2>&1; then
    echo "::error::VALHEIM_SERVER_PASSWORDS has no password (5+ characters) for server \"${name}\"."
    echo "Keys found: $(printf '%s' "$trimmed" | jq -r 'keys | join(", ")')"
    missing=1
  fi
done

exit $missing
