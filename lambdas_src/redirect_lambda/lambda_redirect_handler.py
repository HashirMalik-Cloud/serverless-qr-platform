import json
import boto3
from datetime import datetime
import os

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ.get("TABLE_NAME"))

CORS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "*",
    "Access-Control-Allow-Methods": "*"
}

def detect_device(ua):
    ua = ua.lower()
    if "mobile" in ua:
        return "mobile"
    if "tablet" in ua:
        return "tablet"
    return "desktop"

def lambda_handler(event, context):
    try:
        qr_id = event.get("queryStringParameters", {}).get("id")
        if not qr_id:
            return {
                "statusCode": 400,
                "headers": CORS,
                "body": json.dumps({"error": "Missing QR ID"})
            }

        user_agent = event.get("headers", {}).get("User-Agent", "")
        device = detect_device(user_agent)

        response = table.get_item(Key={"qrId": qr_id})
        item = response.get("Item")

        if not item:
            return {
                "statusCode": 404,
                "headers": CORS,
                "body": json.dumps({"error": "QR code not found"})
            }

        redirect_url = item.get(f"url_{device}", item.get("originalUrl"))

        table.update_item(
            Key={"qrId": qr_id},
            UpdateExpression="SET scanCount = scanCount + :x, lastScanAt = :t",
            ExpressionAttributeValues={
                ":x": 1,
                ":t": datetime.utcnow().isoformat()
            }
        )

        # 302 REDIRECT WITH CORS
        headers = {"Location": redirect_url}
        headers.update(CORS)

        return {
            "statusCode": 302,
            "headers": headers,
            "body": ""
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": CORS,
            "body": json.dumps({"error": str(e)})
        }
