#!/usr/bin/env bash
# Decides which stacks a workflow run should touch and writes
# "flags=<terramate run flags>" to $GITHUB_OUTPUT.
#
#   - only files inside stacks/shared or stacks/servers/<name> changed
#       -> just those stacks (terramate --changed)
#   - anything shared by all servers changed (the module, terramate config,
#     trigger-service, CI scripts/workflows) or the base is unknown
#       -> every valheim stack
#
# Usage: select-stacks.sh <base-commit-or-ref>
set -euo pipefail

BASE="${1:-}"
ALL="--tags valheim"
CHANGED="--tags valheim --changed"

if [ -z "$BASE" ] || [ "$BASE" = "0000000000000000000000000000000000000000" ] \
   || ! git rev-parse --verify --quiet "$BASE^{commit}" >/dev/null; then
  echo "No usable base commit - running all stacks."
  echo "flags=$ALL" >> "$GITHUB_OUTPUT"
  exit 0
fi

files=$(git diff --name-only "$BASE"...HEAD)
echo "Changed files:"; echo "$files" | sed 's/^/  /'

if echo "$files" | grep -Eq '^(modules/|terramate\.tm\.hcl|trigger-service/|\.github/)'; then
  echo "Shared code changed - running all stacks."
  echo "flags=$ALL" >> "$GITHUB_OUTPUT"
else
  echo "Only stack-specific files changed - running changed stacks."
  echo "flags=$CHANGED" >> "$GITHUB_OUTPUT"
fi
