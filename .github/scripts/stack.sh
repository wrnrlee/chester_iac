#!/usr/bin/env bash
# Plans or applies ONE stack. Run by `terramate run` inside the stack dir.
#
#   stack.sh plan   read-only plan; writes $GITHUB_WORKSPACE/plans/<stack>.md
#   stack.sh apply  plan + apply; appends outputs to the job summary
set -euo pipefail

MODE="${1:?usage: stack.sh plan|apply}"
STACK="$(git rev-parse --show-prefix)"; STACK="${STACK%/}"   # e.g. stacks/servers/youmadbro
STATE="gs://${TF_STATE_BUCKET:?}/${STACK}/default.tfstate"
OUT="${GITHUB_WORKSPACE:?}/plans"
mkdir -p "$OUT"

echo "::group::${MODE} ${STACK}"

if [ "$MODE" = "plan" ]; then
  # The read-only planner can't create a state file. Until this stack's
  # first deploy has created one, plan against empty local state - which
  # is exactly what that first deploy starts from.
  fresh=false
  if ! err=$(gcloud storage ls "$STATE" 2>&1 >/dev/null); then
    if echo "$err" | grep -q "matched no objects"; then
      fresh=true
      rm -f _generated_backend.tf
    else
      echo "::error::Could not check state for ${STACK}: ${err}"
      exit 1
    fi
  fi

  terraform init -input=false
  terraform validate
  terraform plan -input=false -lock=false -no-color -out=tfplan

  {
    echo "#### \`${STACK}\`"
    if [ "$fresh" = true ]; then
      echo "> Not deployed yet - planned against empty state."
    fi
    echo '```'
    terraform show -no-color tfplan
    echo '```'
  } > "${OUT}/${STACK//\//_}.md"

elif [ "$MODE" = "apply" ]; then
  terraform init -input=false
  terraform validate
  terraform plan -input=false -out=tfplan
  terraform apply -input=false -auto-approve tfplan

  {
    echo "### \`${STACK}\` deployed"
    echo '```'
    terraform output -no-color
    echo '```'
  } >> "$GITHUB_STEP_SUMMARY"
else
  echo "unknown mode: $MODE" >&2
  exit 2
fi

echo "::endgroup::"
