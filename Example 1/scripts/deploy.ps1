# ==============================================================================
# deploy.ps1 — Build and deploy the SAM application to AWS (Windows)
# ==============================================================================
# Usage (PowerShell):
#   .\scripts\deploy.ps1
#
# If you see "running scripts is disabled", run once as Administrator:
#   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
# ==============================================================================

$ErrorActionPreference = "Stop"

# ── Resolve paths ─────────────────────────────────────────────────────────────
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir   = Split-Path -Parent $ScriptDir
$EnvFile   = Join-Path $RootDir ".env"

# ── Load .env ─────────────────────────────────────────────────────────────────
if (-not (Test-Path $EnvFile)) {
    Write-Host "ERROR: .env file not found at $EnvFile" -ForegroundColor Red
    Write-Host "       Run: copy example.env .env   then fill in your AWS credentials."
    exit 1
}

Write-Host "Loading credentials from .env ..."
Get-Content $EnvFile | Where-Object { $_ -notmatch '^\s*#' -and $_ -match '=' } | ForEach-Object {
    $parts = $_ -split '=', 2
    $key   = $parts[0].Trim()
    $val   = $parts[1].Trim()
    [System.Environment]::SetEnvironmentVariable($key, $val, 'Process')
}

# ── Validate required variables ───────────────────────────────────────────────
$RequiredVars = @("AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "AWS_DEFAULT_REGION", "STACK_NAME")
foreach ($var in $RequiredVars) {
    $val = [System.Environment]::GetEnvironmentVariable($var, 'Process')
    if ([string]::IsNullOrWhiteSpace($val) -or $val -match 'EXAMPLE|YOUR_') {
        Write-Host "ERROR: $var is not set or still contains a placeholder value in .env" -ForegroundColor Red
        exit 1
    }
}

$StackName = [System.Environment]::GetEnvironmentVariable("STACK_NAME",           'Process')
$Region    = [System.Environment]::GetEnvironmentVariable("AWS_DEFAULT_REGION",   'Process')

Set-Location $RootDir

# ── Build ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "==> Step 1/2: Building Lambda packages ..."
sam build
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# ── Deploy ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "==> Step 2/2: Deploying stack '$StackName' to region '$Region' ..."
sam deploy `
    --stack-name $StackName `
    --region     $Region `
    --capabilities CAPABILITY_IAM `
    --resolve-s3 `
    --no-confirm-changeset `
    --no-fail-on-empty-changeset
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "===================================================================" -ForegroundColor Green
Write-Host " Deployment complete!"                                               -ForegroundColor Green
Write-Host " Stack name : $StackName"
Write-Host " Region     : $Region"
Write-Host ""
Write-Host " Copy the 'ApiBaseUrl' value from the Outputs above to test."
Write-Host " See README.md Step 6 for test commands."
Write-Host "===================================================================" -ForegroundColor Green
