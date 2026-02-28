#!/usr/bin/env bash
# ==============================================================================
# deploy.sh — Build and deploy the SAM application to AWS
# ==============================================================================
# Usage: bash scripts/deploy.sh
# ==============================================================================

set -euo pipefail

# ── Load .env ─────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: .env file not found at $ENV_FILE"
  echo "       Run:  cp example.env .env  then fill in your AWS credentials."
  exit 1
fi

echo "Loading credentials from .env ..."
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

# ── Validate required variables ───────────────────────────────────────────────
REQUIRED_VARS=("AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY" "AWS_DEFAULT_REGION" "STACK_NAME")
for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var:-}" ] || [[ "${!var}" == *"EXAMPLE"* ]] || [[ "${!var}" == *"YOUR_"* ]]; then
    echo "ERROR: $var is not set or still contains a placeholder value in .env"
    exit 1
  fi
done

cd "$ROOT_DIR"

# ── Build ─────────────────────────────────────────────────────────────────────
echo ""
echo "==> Step 1/2: Building Lambda packages ..."
sam build

# ── Deploy ────────────────────────────────────────────────────────────────────
echo ""
echo "==> Step 2/2: Deploying stack '$STACK_NAME' to region '$AWS_DEFAULT_REGION' ..."
sam deploy \
  --stack-name "$STACK_NAME" \
  --region     "$AWS_DEFAULT_REGION" \
  --capabilities CAPABILITY_IAM \
  --resolve-s3 \
  --no-confirm-changeset \
  --no-fail-on-empty-changeset

echo ""
echo "==================================================================="
echo " Deployment complete!"
echo " Stack name : $STACK_NAME"
echo " Region     : $AWS_DEFAULT_REGION"
echo ""
echo " Copy the 'CreateJobEndpoint' URL from the Outputs above to test."
echo " See README.md Step 6 for curl test commands."
echo "==================================================================="
