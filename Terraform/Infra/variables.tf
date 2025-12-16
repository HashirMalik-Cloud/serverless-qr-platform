variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_prefix" {
  description = "Unique prefix for resource names"
  type        = string
  default     = "hashir-qr"
}

variable "tags" {
  description = "Global tags applied to all resources"
  type        = map(string)
  default = {
    Project   = "qr-generator"
    ManagedBy = "terraform"
  }
}

variable "callback_urls" {
  type    = list(string)
  default = ["http://localhost:3000"]
}

variable "logout_urls" {
  type    = list(string)
  default = ["http://localhost:3000"]
}

variable "cognito_domain_prefix" {
  type    = string
  default = "hashir-qr-auth"
}
