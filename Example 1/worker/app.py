"""
Lambda 2 — Worker (Background Processor)
-----------------------------------------
Invoked asynchronously by the Create Job Lambda.

Simulates a three-stage processing pipeline to mimic real-world workloads:
  Stage 1 — OCR        : extract text features       (~2s)
  Stage 2 — ML         : run inference / sentiment   (~2s)
  Stage 3 — Search     : query a document index      (~1s)

Status lifecycle this Lambda drives:
  PENDING → IN_PROGRESS → DONE  (or ERROR on failure)
"""

import json
import os
import time

import boto3

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])


# ── Simulated processing stages ───────────────────────────────────────────────

def simulate_ocr(text: str) -> dict:
    """Simulate OCR: extract character and word statistics from text."""
    time.sleep(2)
    word_count = len(text.split())
    char_count = len(text)
    return {
        "stage": "ocr",
        "charCount": char_count,
        "wordCount": word_count,
        "preview": text[:80] + ("..." if len(text) > 80 else ""),
    }


def simulate_ml(text: str) -> dict:
    """Simulate ML inference: naive keyword-based sentiment detection."""
    time.sleep(2)
    positive_words = {"great", "good", "excellent", "amazing", "love", "best", "happy"}
    negative_words = {"bad", "terrible", "awful", "hate", "worst", "poor", "sad"}

    tokens = text.lower().split()
    pos_hits = sum(1 for t in tokens if t in positive_words)
    neg_hits = sum(1 for t in tokens if t in negative_words)

    if pos_hits > neg_hits:
        sentiment = "POSITIVE"
        confidence = round(0.6 + min(pos_hits * 0.05, 0.35), 2)
    elif neg_hits > pos_hits:
        sentiment = "NEGATIVE"
        confidence = round(0.6 + min(neg_hits * 0.05, 0.35), 2)
    else:
        sentiment = "NEUTRAL"
        confidence = 0.50

    return {
        "stage": "ml_inference",
        "sentiment": sentiment,
        "confidence": confidence,
        "tokenCount": len(tokens),
    }


def simulate_search(text: str) -> dict:
    """Simulate a heavy document-index search based on word frequency."""
    time.sleep(1)
    words = text.lower().split()
    frequency = {}
    for word in words:
        if len(word) > 3:          # ignore very short stop-words
            frequency[word] = frequency.get(word, 0) + 1

    top_keywords = sorted(frequency, key=frequency.get, reverse=True)[:5]
    related_doc_count = len(top_keywords) * 7   # deterministic mock result

    return {
        "stage": "search",
        "topKeywords": top_keywords,
        "relatedDocumentsFound": related_doc_count,
    }


# ── Helper: update DynamoDB status ────────────────────────────────────────────

def update_status(job_id: str, status: str, extra: dict = None):
    update_expr = "SET #s = :s, updatedAt = :t"
    attr_names = {"#s": "status"}
    attr_values = {":s": status, ":t": int(time.time())}

    if extra:
        for i, (key, val) in enumerate(extra.items()):
            placeholder = f":v{i}"
            update_expr += f", {key} = {placeholder}"
            attr_values[placeholder] = val

    table.update_item(
        Key={"jobId": job_id},
        UpdateExpression=update_expr,
        ExpressionAttributeNames=attr_names,
        ExpressionAttributeValues=attr_values,
    )


# ── Main handler ──────────────────────────────────────────────────────────────

def lambda_handler(event, context):
    job_id = event["jobId"]

    # Fetch job text from DynamoDB
    item = table.get_item(Key={"jobId": job_id}).get("Item", {})
    text = item.get("text", "")

    # Mark job as in-progress
    update_status(job_id, "IN_PROGRESS")

    try:
        # ── Stage 1: OCR ──────────────────────────────────────────────────────
        ocr_result = simulate_ocr(text)

        # ── Stage 2: ML Inference ─────────────────────────────────────────────
        ml_result = simulate_ml(text)

        # ── Stage 3: Heavy Search ─────────────────────────────────────────────
        search_result = simulate_search(text)

        # ── Mark job as done ──────────────────────────────────────────────────
        update_status(
            job_id,
            "DONE",
            extra={
                "result": json.dumps(
                    {
                        "ocr": ocr_result,
                        "mlInference": ml_result,
                        "search": search_result,
                    }
                )
            },
        )

    except Exception as exc:
        # Mark job as errored so the caller can detect failure via polling
        update_status(job_id, "ERROR", extra={"errorMessage": str(exc)})
        raise
