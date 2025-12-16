variable "project_prefix" {
  type        = string
  description = "Prefix used for API Gateway resources"
  default     = "hashir-qr"
}

variable "lambda_generate_qr_arn" {
  type        = string
  description = "ARN for generate QR lambda"
  default     = ""
}

variable "lambda_get_qr_arn" {
  type        = string
  description = "ARN for get QR lambda (optional)"
  default     = ""
}

variable "lambda_redirect_arn" {
  type        = string
  description = "ARN for redirect lambda (optional)"
  default     = ""
}

variable "lambda_pdf_arn" {
  type        = string
  description = "ARN for pdf lambda (optional)"
  default     = ""
}

variable "enable_get_qr" {
  type    = bool
  default = true
}

variable "enable_redirect" {
  type    = bool
  default = true
}

variable "enable_pdf" {
  type    = bool
  default = true
}

# IMPORTANT: default false so we don't break existing infra when you don't have authorizer
variable "enable_cognito" {
  type    = bool
  default = false
}

variable "cognito_user_pool_id" {
  type    = string
  default = ""
}

variable "tags" {
  type = map(string)
  default = {
    Project   = "qr-generator"
    ManagedBy = "terraform"
  }
}

# kept for compatibility if you want to pass explicit resource map later
variable "all_resources" {
  description = "Map of all API Gateway resource IDs for which OPTIONS methods should be created"
  type        = map(string)
  default     = {}
}

variable "import_api_authorizer_id" {
  type        = string
  description = "If set, use this existing API Gateway authorizer id. Leave empty to let module create authorizer when enable_cognito = true."
  default     = ""
}
