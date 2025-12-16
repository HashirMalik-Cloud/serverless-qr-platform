import boto3
import json
import base64
from reportlab.lib.pagesizes import letter
from reportlab.pdfgen import canvas
import tempfile
import os

dynamodb = boto3.client("dynamodb")
s3 = boto3.client("s3")

CORS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "*",
    "Access-Control-Allow-Methods": "*"
}

def lambda_handler(event, context):
    try:
        qr_id = event["queryStringParameters"]["id"]

        item = dynamodb.get_item(
            TableName=os.environ["TABLE_NAME"],
            Key={"qrId": {"S": qr_id}}
        )

        if "Item" not in item:
            return {
                "statusCode": 404,
                "headers": CORS,
                "body": json.dumps({"error": "QR not found"})
            }

        key = item["Item"]["qrImageKey"]["S"]

        image_obj = s3.get_object(
            Bucket=os.environ["IMAGES_BUCKET"],
            Key=key
        )
        image_bytes = image_obj["Body"].read()

        pdf_path = f"/tmp/{qr_id}.pdf"
        c = canvas.Canvas(pdf_path, pagesize=letter)

        c.setFont("Helvetica-Bold", 20)
        c.drawString(100, 750, "QR Code")

        img_temp = f"/tmp/{qr_id}.png"
        with open(img_temp, "wb") as f:
            f.write(image_bytes)

        c.drawImage(img_temp, 100, 500, 200, 200)
        c.setFont("Helvetica", 12)
        c.drawString(100, 470, f"QR ID: {qr_id}")
        c.save()

        s3.upload_file(
            pdf_path,
            os.environ["PDF_BUCKET"],
            f"{qr_id}.pdf",
            ExtraArgs={"ContentType": "application/pdf"}
        )

        url = s3.generate_presigned_url(
            ClientMethod="get_object",
            Params={
                "Bucket": os.environ["PDF_BUCKET"],
                "Key": f"{qr_id}.pdf"
            },
            ExpiresIn=3600
        )

        return {
            "statusCode": 200,
            "headers": CORS,
            "body": json.dumps({"pdfUrl": url})
        }

    except Exception as e:
        return {
            "statusCode": 500",
            "headers": CORS,
            "body": json.dumps({"error": str(e)})
        }
