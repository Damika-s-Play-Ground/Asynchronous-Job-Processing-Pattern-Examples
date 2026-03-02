# ==============================================================================
# teardown.ps1 — Delete all AWS resources created by this SAM stack (Windows)
# ==============================================================================
# Usage (PowerShell):
#   .\scripts\teardown.ps1
#
# This script will permanently delete:
#   - The CloudFormation stack (and all resources in it)
#   - Lambda functions, API Gateway, DynamoDB table
#   - The auto-created S3 bucket used for SAM artifacts
# ==============================================================================

$ErrorActionPreference = "Stop"

# ── Resolve paths ─────────────────────────────────────────────────────────────
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir   = Split-Path -Parent $ScriptDir
$EnvFile   = Join-Path $RootDir ".env"

# ── Load .env ─────────────────────────────────────────────────────────────────
if (-not (Test-Path $EnvFile)) {
    Write-Host "ERROR: .env file not found at $EnvFile" -ForegroundColor Red
    exit 1
}

Write-Host "Loading credentials from .env ..."
Get-Content $EnvFile | Where-Object { $_ -notmatch '^\s*#' -and $_ -match '=' } | ForEach-Object {
    $parts = $_ -split '=', 2
    $key   = $parts[0].Trim()
    $val   = $parts[1].Trim()
    [System.Environment]::SetEnvironmentVariable($key, $val, 'Process')
}

$StackName = [System.Environment]::GetEnvironmentVariable("STACK_NAME",         'Process')
$Region    = [System.Environment]::GetEnvironmentVariable("AWS_DEFAULT_REGION", 'Process')

if ([string]::IsNullOrWhiteSpace($StackName)) { $StackName = "async-job-processing-demo" }
if ([string]::IsNullOrWhiteSpace($Region))    { $Region    = "us-east-1" }

# ── Confirmation prompt ───────────────────────────────────────────────────────
Write-Host ""
Write-Host "===================================================================" -ForegroundColor Yellow
Write-Host " WARNING: This will permanently delete all AWS resources for:"       -ForegroundColor Yellow
Write-Host "   Stack  : $StackName"
Write-Host "   Region : $Region"
Write-Host ""
Write-Host " Resources that will be destroyed:"
Write-Host "   - API Gateway"
Write-Host "   - Lambda functions (CreateJob, Worker, GetJob)"
Write-Host "   - DynamoDB table (all job data will be lost)"
Write-Host "   - IAM roles created by SAM"
Write-Host "   - S3 bucket used for SAM deployment artifacts"
Write-Host "===================================================================" -ForegroundColor Yellow
Write-Host ""
$Confirm = Read-Host "Type 'yes' to confirm teardown"

if ($Confirm -ne "yes") {
    Write-Host "Teardown cancelled. No resources were deleted."
    exit 0
}

# ── Delete the SAM stack ──────────────────────────────────────────────────────
Write-Host ""
Write-Host "==> Deleting stack '$StackName' ..."
sam delete --stack-name $StackName --region $Region --no-prompts
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "===================================================================" -ForegroundColor Green
Write-Host " Teardown complete."                                                 -ForegroundColor Green
Write-Host " All AWS resources for stack '$StackName' have been deleted."
Write-Host " You will no longer be billed for these resources."
Write-Host "===================================================================" -ForegroundColor Green
