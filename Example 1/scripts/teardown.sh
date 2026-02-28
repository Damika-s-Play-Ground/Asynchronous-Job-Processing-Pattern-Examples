#!/usr/bin/env bash
# ==============================================================================
# teardown.sh — Delete all AWS resources created by this SAM stack
# ==============================================================================
# Usage: bash scripts/teardown.sh
#
# This script will permanently delete:
#   - The CloudFormation stack (and all resources in it)
#   - Lambda functions, API Gateway, DynamoDB table
#   - The auto-created S3 bucket used for SAM artifacts
# ==============================================================================

set -euo pipefail

# ── Load .env ─────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: .env file not found at $ENV_FILE"
  exit 1
fi

echo "Loading credentials from .env ..."
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

STACK="${STACK_NAME:-async-job-processing-demo}"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"

# ── Confirmation prompt ───────────────────────────────────────────────────────
echo ""
echo "==================================================================="
echo " WARNING: This will permanently delete all AWS resources for:"
echo "   Stack  : $STACK"
echo "   Region : $REGION"
echo ""
echo " Resources that will be destroyed:"
echo "   - API Gateway"
echo "   - Lambda functions (CreateJob, Worker, GetJob)"
echo "   - DynamoDB table (all job data will be lost)"
echo "   - IAM roles created by SAM"
echo "   - S3 bucket used for SAM deployment artifacts"
echo "==================================================================="
echo ""
read -rp "Type 'yes' to confirm teardown: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Teardown cancelled. No resources were deleted."
  exit 0
fi

# ── Delete the SAM stack ──────────────────────────────────────────────────────
echo ""
echo "==> Deleting stack '$STACK' ..."
sam delete \
  --stack-name "$STACK" \
  --region     "$REGION" \
  --no-prompts

echo ""
echo "==================================================================="
echo " Teardown complete."
echo " All AWS resources for stack '$STACK' have been deleted."
echo " You will no longer be billed for these resources."
echo "==================================================================="
