"""
Lambda 3 — Get Job Status
--------------------------
Handles GET /jobs/{id} requests.

Returns the full job record from DynamoDB, including:
  - jobId
  - status    : PENDING | IN_PROGRESS | DONE | ERROR
  - text      : original submitted text
  - result    : processing output (present when status = DONE)
  - createdAt : Unix timestamp
  - updatedAt : Unix timestamp of last status change
"""

import json
import os
from decimal import Decimal

import boto3

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])


class DecimalEncoder(json.JSONEncoder):
    """DynamoDB stores numbers as Decimal; convert them for JSON serialization."""

    def default(self, obj):
        if isinstance(obj, Decimal):
            return int(obj) if obj % 1 == 0 else float(obj)
        return super().default(obj)


def lambda_handler(event, context):
    job_id = event["pathParameters"]["id"]
    print(json.dumps({"level": "INFO", "message": "GetJob invoked", "requestId": context.aws_request_id, "jobId": job_id}))

    response = table.get_item(Key={"jobId": job_id})
    item = response.get("Item")

    if not item:
        print(json.dumps({"level": "WARN", "message": "Job not found", "jobId": job_id}))
        return {
            "statusCode": 404,
            "body": json.dumps({"error": f"Job '{job_id}' not found"}),
        }

    # Parse the stored result JSON string back into an object for a cleaner response
    if "result" in item and isinstance(item["result"], str):
        try:
            item["result"] = json.loads(item["result"])
        except (json.JSONDecodeError, TypeError):
            print(json.dumps({"level": "WARN", "message": "Result field is not valid JSON string", "jobId": job_id}))
            pass

    print(json.dumps({"level": "INFO", "message": "GetJob completed", "jobId": job_id, "status": item.get("status"), "statusCode": 200}))
    return {
        "statusCode": 200,
        "body": json.dumps(item, cls=DecimalEncoder),
    }
