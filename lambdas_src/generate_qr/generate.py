import json
import uuid
import boto3
import os
from datetime import datetime
import segno

# AWS Clients
s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")

# Environment Variables
S3_BUCKET = os.environ.get("IMAGES_BUCKET")
DDB_TABLE = os.environ.get("TABLE_NAME")

# CORS Headers
CORS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "*",
    "Access-Control-Allow-Methods": "*"
}

def safe_json_parse(body):
    try:
        return json.loads(body) if body else {}
    except Exception:
        return {}

def lambda_handler(event, context):
    print("===== EVENT RECEIVED =====")
    print(json.dumps(event))

    try:
        # ---------- PARSE BODY ----------
        raw_body = event.get("body")
        body = raw_body if isinstance(raw_body, dict) else safe_json_parse(raw_body)

        print("Parsed Body:", body)

        original_url = body.get("originalUrl")
        theme = body.get("theme", "#000000")
        expiry_time = body.get("expiryTime")
        user_id = body.get("userId", "anonymous")

        if not original_url:
            return {
                "statusCode": 400,
                "headers": CORS,
                "body": json.dumps({"error": "originalUrl is required"})
            }

        # ---------- GENERATE QR (PDF) ----------
        qr_id = str(uuid.uuid4())
        file_name = f"{qr_id}.pdf"
        file_path = f"/tmp/{file_name}"

        qr = segno.make(original_url)

        # Save as PDF (NO Pillow needed)
        qr.save(
            file_path,
            kind="pdf",
            scale=10,
            dark=theme,
            light="white"
        )

        # ---------- UPLOAD TO S3 ----------
        s3.upload_file(
            file_path,
            S3_BUCKET,
            file_name,
            ExtraArgs={"ContentType": "application/pdf"}
        )

        s3_url = f"https://{S3_BUCKET}.s3.amazonaws.com/{file_name}"

        # ---------- SAVE METADATA ----------
        table = dynamodb.Table(DDB_TABLE)
        table.put_item(
            Item={
                "qrId": qr_id,
                "userId": user_id,
                "originalUrl": original_url,
                "theme": theme,
                "expiryTime": expiry_time,
                "scanCount": 0,
                "createdAt": datetime.utcnow().isoformat(),
                "lastScanAt": None,
                "qrFileKey": file_name
            }
        )

        # ---------- RESPONSE ----------
        return {
            "statusCode": 200,
            "headers": CORS,
            "body": json.dumps({
                "qrId": qr_id,
                "qrPdfUrl": s3_url
            })
        }

    except Exception as e:
        print("ERROR:", str(e))
        return {
            "statusCode": 500,
            "headers": CORS,
            "body": json.dumps({
                "error": "Internal Server Error",
                "details": str(e)
            })
        }
