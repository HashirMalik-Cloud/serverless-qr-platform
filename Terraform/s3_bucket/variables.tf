// modules/s3_bucket/variables.tf
variable "project_prefix" {
  description = "Project prefix used in resource names"
  type        = string
}

variable "name_suffix" {
  description = "Suffix used for this bucket (e.g. logs, images)"
  type        = string
}

variable "tags" {
  description = "Map of tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "enable_versioning" {
  description = "Whether to enable versioning"
  type        = bool
  default     = false
}

variable "encryption_type" {
  description = "S3 encryption type: SSE or KMS"
  type        = string
  default     = "SSE"
}

# Lifecycle configuration variables
variable "transition_days" {
  description = "Days until transition to cheaper storage"
  type        = number
  default     = 30
}

variable "transition_to" {
  description = "Storage class to transition to (STANDARD_IA, ONEZONE_IA, etc.)"
  type        = string
  default     = "STANDARD_IA"
}

variable "expiration_days" {
  description = "Number of days until objects expire"
  type        = number
  default     = 365
}
