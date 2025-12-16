// modules/s3_bucket/main.tf
resource "random_id" "bucket_id" {
  byte_length = 4
}

resource "aws_s3_bucket" "this" {
  bucket = "${var.project_prefix}-${var.name_suffix}-${random_id.bucket_id.hex}"

  tags = merge(var.tags, { Name = "${var.project_prefix}-${var.name_suffix}" })

  # REMOVE ACL to avoid ACL error (Object Ownership = bucket owner enforced)
  # acl = "private"  <-- removed

  # Lifecycle configuration
  lifecycle_rule {
    id      = "keep-recent"
    enabled = true

    expiration {
      days = var.expiration_days
    }

    transition {
      days          = var.transition_days
      storage_class = var.transition_to
    }
  }

  force_destroy = false
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_kms_key" "s3_key" {
  count                   = var.encryption_type == "KMS" ? 1 : 0
  description             = "KMS key for ${var.project_prefix}-${var.name_suffix}"
  deletion_window_in_days = 30
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.encryption_type == "KMS" ? "aws:kms" : "AES256"
      kms_master_key_id = var.encryption_type == "KMS" ? aws_kms_key.s3_key[0].arn : null
    }
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
