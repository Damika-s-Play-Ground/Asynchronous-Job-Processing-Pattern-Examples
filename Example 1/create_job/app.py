"""
Lambda 1 — Create Job
---------------------
Handles POST /jobs requests.

Flow:
  1. Parse the text payload from the request body
  2. Generate a unique job ID
  3. Store the job as PENDING in DynamoDB
  4. Asynchronously invoke the Worker Lambda (fire-and-forget)
  5. Return the job ID and PENDING status immediately to the caller
"""

import json
import os
import time
import uuid

import boto3

dynamodb = boto3.resource("dynamodb")
lambda_client = boto3.client("lambda")

table = dynamodb.Table(os.environ["TABLE_NAME"])
worker_name = os.environ["WORKER_NAME"]


def lambda_handler(event, context):
    # ── Parse request body ────────────────────────────────────────────────────
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "Invalid JSON in request body"}),
        }

    text = body.get("text", "").strip()
    if not text:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "Field 'text' is required and must not be empty"}),
        }

    # ── Create job record in DynamoDB ─────────────────────────────────────────
    job_id = str(uuid.uuid4())
    now = int(time.time())

    table.put_item(
        Item={
            "jobId": job_id,
            "status": "PENDING",
            "text": text,
            "createdAt": now,
            "updatedAt": now,
        }
    )

    # ── Fire-and-forget: invoke worker asynchronously ─────────────────────────
    # InvocationType="Event" returns immediately (202) without waiting for the
    # worker to finish. The worker will update the job record independently.
    lambda_client.invoke(
        FunctionName=worker_name,
        InvocationType="Event",
        Payload=json.dumps({"jobId": job_id}),
    )

    # ── Return job ID to caller immediately ───────────────────────────────────
    return {
        "statusCode": 202,
        "body": json.dumps(
            {
                "jobId": job_id,
                "status": "PENDING",
                "message": "Job accepted. Poll GET /jobs/{jobId} for status updates.",
            }
        ),
    }
