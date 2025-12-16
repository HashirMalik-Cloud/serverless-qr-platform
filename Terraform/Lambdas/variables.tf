// modules/lambdas/variables.tf
variable "project_prefix" {
  type = string
}

variable "dynamodb_table" {
  type = string
}

variable "s3_bucket_images" {
  type = string
  description = "Bucket used to store QR images"
}

variable "scan_logs_bucket_name" {
  type = string
  description = "Bucket name where scan JSON logs will be written"
}

variable "tags" {
  type = map(string)
  default = {}
}

# Additional redirect lambda env vars (map) if you already had some
variable "redirect_env_vars" {
  type = map(string)
  default = {}
}

variable "images_bucket" {
  type        = string
  description = "S3 bucket name for images"
}

variable "pdf_bucket" {
  type        = string
  description = "S3 bucket name for PDFs"
}

variable "api_gateway_execution_arn" {
  type        = string
  description = "API Gateway execution ARN for Lambda permission"
  default     = null  # ✅ Make it optional
}
