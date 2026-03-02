# Async Text Processing API — Example 1 (Basic)

A minimal, deployable demonstration of the **Asynchronous Job Processing Pattern** using AWS serverless services.

```
POST /jobs  →  job stored as PENDING  →  worker processes in background  →  GET /jobs/{id} to poll
```

This is **Example 1** (basic version). It covers the core pattern end-to-end:
- simulated OCR extraction
- simulated ML sentiment inference
- simulated heavy document search

---

## Architecture

```
Client
  │
  │  POST /jobs  {"text": "..."}
  ▼
API Gateway
  │
  ▼
Lambda: CreateJob
  │  ├── writes job record (PENDING) → DynamoDB
  │  └── invokes Worker async (fire-and-forget, returns 202 immediately)
  │
  ▼
Lambda: Worker  (runs independently, ~5s)
  │  ├── sets status → IN_PROGRESS
  │  ├── Stage 1: simulate OCR     (~2s)
  │  ├── Stage 2: simulate ML      (~2s)
  │  ├── Stage 3: simulate Search  (~1s)
  │  └── sets status → DONE (or ERROR)
  │
  ▼
DynamoDB: JobsTable
  │
  ▼
Client polls:  GET /jobs/{jobId}  (until status = DONE)
```

---

## Prerequisites

Before you begin, install the following tools:

| Tool | Purpose | Install guide |
|------|---------|--------------|
| **AWS CLI v2** | Authenticate with AWS | https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html |
| **AWS SAM CLI** | Build and deploy serverless apps | https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html |
| **Python 3.11+** | Runtime for Lambda functions | https://www.python.org/downloads/ |
| **Git** | Clone the repository | https://git-scm.com/downloads |

Verify installations:

```bash
aws --version
sam --version
python3 --version
```

---

## Step 1 — Clone the repository

```bash
git clone https://github.com/Damika-s-Play-Ground/Asynchronous-Job-Processing-Pattern-Examples.git
cd "Example 1"
```

---

## Step 2 — Create an AWS Free Tier account

> Skip this step if you already have an AWS account.

1. Go to https://aws.amazon.com/free/
2. Click **Create a Free Account**
3. Complete sign-up (credit card required for identity verification, but Free Tier services are free within limits)
4. Sign in to the **AWS Management Console**

Free Tier limits relevant to this demo (more than enough for experimentation):
- **Lambda**: 1,000,000 free requests/month
- **DynamoDB**: 25 GB storage, 25 read/write capacity units/month
- **API Gateway**: 1,000,000 HTTP API calls/month (first 12 months)

---

## Step 3 — Create an IAM user and access keys

AWS access keys are how the SAM CLI authenticates on your behalf.

1. In the AWS Console, search for **IAM** and open it
2. In the left sidebar click **Users** → **Create user**
3. Set a username (e.g. `sam-deploy-user`) and click **Next**
4. On the **Set permissions** page select **Attach policies directly**
5. Search for and attach **AdministratorAccess**
   > Note: AdministratorAccess is used here for convenience in a personal experiment.
   > In production, scope permissions to only what SAM needs.
6. Click **Next** → **Create user**
7. Open the user you just created → **Security credentials** tab
8. Under **Access keys** click **Create access key**
9. Select **Command Line Interface (CLI)** → check the confirmation box → **Next**
10. Click **Create access key**
11. **Copy both values now** — the secret key is only shown once:
    - `Access key ID`     (looks like `AKIA...`)
    - `Secret access key` (looks like `wJalr...`)

---

## Step 4 — Configure your .env file

```bash
# In the project root:
cp example.env .env
```

Open `.env` in any text editor and replace the placeholder values:

```bash
# Replace with your real values from Step 3
AWS_ACCESS_KEY_ID=AKIA...your...key...here
AWS_SECRET_ACCESS_KEY=wJalr...your...secret...here

# Choose the AWS region closest to you. Examples:
#   us-east-1      (US East — N. Virginia)
#   eu-west-1      (Europe — Ireland)
#   ap-southeast-1 (Asia Pacific — Singapore)
AWS_DEFAULT_REGION=us-east-1

# Stack name — you can keep this default
STACK_NAME=async-job-processing-demo
```

Save the file. It is listed in `.gitignore` and will never be committed.

---

## Step 5 — Deploy to AWS

```bash
bash scripts/deploy.sh
```

This script will:
1. Load your credentials from `.env`
2. Run `sam build` — packages each Lambda function
3. Run `sam deploy` — creates/updates the CloudFormation stack on AWS

First deploy takes about 2–3 minutes. You will see output like:

```
CloudFormation outputs from deployed stack
--------------------------------------------
Key         CreateJobEndpoint
Value       https://abc123.execute-api.us-east-1.amazonaws.com/Prod/jobs

Key         GetJobEndpoint
Value       https://abc123.execute-api.us-east-1.amazonaws.com/Prod/jobs/{id}
```

**Copy the `CreateJobEndpoint` URL** — you will need it in Step 6.

---

## Step 6 — Test the API

Replace `<YOUR_API_URL>` with the `CreateJobEndpoint` from Step 5.

### Submit a job

```bash
curl -X POST https://<YOUR_API_URL>/Prod/jobs \
  -H "Content-Type: application/json" \
  -d '{"text": "AWS Lambda is a great serverless compute service"}'
```

Expected response (immediate, ~200ms):

```json
{
  "jobId": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "status": "PENDING",
  "message": "Job accepted. Poll GET /jobs/{jobId} for status updates."
}
```

### Poll for job status

Extract the `jobId` from the previous response and use it to poll the job status:
```bash
curl https://<YOUR_API_URL>/Prod/jobs/<jobId>
```

Poll a few times. You will see the status progress:

**While processing (~5s):**
```json
{
  "jobId": "f47ac10b-...",
  "status": "IN_PROGRESS",
  "text": "AWS Lambda is a great serverless compute service",
  "createdAt": 1709000000,
  "updatedAt": 1709000001
}
```

**When complete:**
```json
{
  "jobId": "f47ac10b-...",
  "status": "DONE",
  "text": "AWS Lambda is a great serverless compute service",
  "createdAt": 1709000000,
  "updatedAt": 1709000006,
  "result": {
    "ocr": {
      "stage": "ocr",
      "charCount": 51,
      "wordCount": 9,
      "preview": "AWS Lambda is a great serverless compute service"
    },
    "mlInference": {
      "stage": "ml_inference",
      "sentiment": "POSITIVE",
      "confidence": 0.65,
      "tokenCount": 9
    },
    "search": {
      "stage": "search",
      "topKeywords": ["lambda", "serverless", "compute", "service"],
      "relatedDocumentsFound": 28
    }
  }
}
```

### Quick poll loop (bash)

```bash
JOB_ID="your-job-id-here"
API_URL="https://<YOUR_API_URL>/Prod"

while true; do
  STATUS=$(curl -s "$API_URL/jobs/$JOB_ID" | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])")
  echo "Status: $STATUS"
  [ "$STATUS" = "DONE" ] || [ "$STATUS" = "ERROR" ] && break
  sleep 1
done
```

---

## Step 7 — Run locally (optional)

You can test the functions on your local machine without deploying to AWS using SAM Local.

> Requires [Docker Desktop](https://www.docker.com/products/docker-desktop/) to be running.

```bash
sam build
sam local start-api
```

In a separate terminal:

```bash
curl -X POST http://127.0.0.1:3000/jobs \
  -H "Content-Type: application/json" \
  -d '{"text": "Test local processing"}'
```

> Note: Local invocation does not support async Lambda invocation, so the worker
> will not be triggered automatically. Use `sam local invoke WorkerFunction`
> with a test payload to test it separately.

---

## Step 8 — Teardown (delete all AWS resources)

When you are done experimenting, run this command to delete every AWS resource
created by this stack and stop all charges:

```bash
bash scripts/teardown.sh
```

You will be prompted to confirm. Type `yes` to proceed.

This deletes:
- API Gateway
- All three Lambda functions
- DynamoDB table (and all stored job data)
- IAM roles created by SAM
- S3 bucket used for SAM deployment artifacts

---

## Project structure

```
Example 1/
├── template.yaml           # SAM template — defines all AWS infrastructure
├── samconfig.toml          # SAM deployment configuration (non-secret)
├── .env                    # Your credentials (gitignored — never commit this)
├── example.env             # Template showing required variables (safe to commit)
├── .gitignore
│
├── create_job/
│   └── app.py              # Lambda 1: POST /jobs — creates job record, fires worker
│
├── worker/
│   └── app.py              # Lambda 2: background worker — simulates OCR, ML, Search
│
├── get_job/
│   └── app.py              # Lambda 3: GET /jobs/{id} — returns status and result
│
├── scripts/
│   ├── deploy.sh           # Build + deploy to AWS
│   └── teardown.sh         # Delete all AWS resources
│
└── README.md
```

---

## Job status lifecycle

```
PENDING → IN_PROGRESS → DONE
                      ↘ ERROR  (if the worker throws an unhandled exception)
```

| Status | Meaning |
|--------|---------|
| `PENDING` | Job created, worker not yet started |
| `IN_PROGRESS` | Worker is actively processing |
| `DONE` | Processing complete, `result` field is populated |
| `ERROR` | Worker failed, `errorMessage` field explains why |

---

## Troubleshooting

**`sam deploy` fails with credential error**
- Double-check `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` in your `.env`
- Ensure the IAM user has `AdministratorAccess` attached (Step 3)

**`sam build` fails**
- Ensure Python 3.11+ is installed: `python3 --version`
- Ensure SAM CLI is up to date: `sam --version`

**API returns 500**
- Open AWS Console → CloudWatch → Log groups → find `/aws/lambda/...CreateJob...` or `...Worker...`
- Lambda logs will show the full Python traceback

**Job stays PENDING forever**
- The worker was not invoked. Check the CreateJob Lambda logs in CloudWatch.
- Ensure the `LambdaInvokePolicy` is correctly applied in `template.yaml`

**Windows users**
- Use **Git Bash** or **WSL2** to run the `.sh` scripts
- Alternatively, manually export the variables in PowerShell and run `sam build` / `sam deploy` directly
