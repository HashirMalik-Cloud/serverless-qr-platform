resource "aws_dynamodb_table" "qr_metadata" {
  name         = "${var.project_prefix}-QRMetadata"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "qrId"

  attribute {
    name = "qrId"
    type = "S"
  }

  ttl {
    attribute_name = var.ttl_attribute_name # "expiryTime"
    enabled        = true
  }

  tags = var.tags
}
