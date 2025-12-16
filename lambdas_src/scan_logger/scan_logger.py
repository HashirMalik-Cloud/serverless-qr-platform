import os
import json
import boto3
from datetime import datetime, timezone
import uuid

s3 = boto3.client("s3")
LOG_BUCKET = os.environ["LOG_BUCKET"]

CORS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "*",
    "Access-Control-Allow-Methods": "*"
}

def now_iso():
    return datetime.now(timezone.utc).isoformat()

def build_key(qr_id):
    now = datetime.now(timezone.utc)
    return f"logs/{qr_id}/{now.year}/{now.month}/{now.day}/{uuid.uuid4().hex}.json"

def lambda_handler(event, context):
    try:
        params = event.get("queryStringParameters") or {}
        qr_id = params.get("qrId")

        if not qr_id:
            return {
                "statusCode": 400,
                "headers": CORS,
                "body": json.dumps({"error": "qrId missing"})
            }

        payload = {
            "qrId": qr_id,
            "scanTime": now_iso(),
            "sourceIp": event.get("requestContext", {})
                              .get("identity", {})
                              .get("sourceIp"),
            "userAgent": event.get("headers", {}).get("User-Agent")
        }

        key = build_key(qr_id)

        s3.put_object(
            Bucket=LOG_BUCKET,
            Key=key,
            Body=json.dumps(payload),
            ContentType="application/json"
        )

        return {
            "statusCode": 200,
            "headers": CORS,
            "body": json.dumps({"status": "logged", "key": key})
        }

    except Exception as e:
        print("ERROR:", str(e))  # CloudWatch
        return {
            "statusCode": 500,
            "headers": CORS,
            "body": json.dumps({"error": str(e)})
        }
