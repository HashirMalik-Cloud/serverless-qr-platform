variable "project_prefix" {
  type        = string
  description = "Prefix used for naming Cognito resources"
}

variable "callback_urls" {
  type        = list(string)
  description = "Allowed redirect URLs after successful login"
  default     = ["http://localhost:3000"]
}

variable "logout_urls" {
  type        = list(string)
  description = "Allowed redirect URLs after logout"
  default     = ["http://localhost:3000"]
}

variable "cognito_domain_prefix" {
  type        = string
  description = "Prefix for Cognito Hosted UI domain (not used when Hosted UI is disabled)"
  default     = ""
}

variable "allowed_oauth_flows" {
  type        = list(string)
  description = "Allowed OAuth flows for the client (kept for compatibility). For pure SDK login you can leave empty or keep ['code']"
  default     = ["code"]
}

variable "allowed_oauth_scopes" {
  type        = list(string)
  description = "Allowed OAuth scopes"
  default     = ["openid", "email", "profile"]
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all Cognito resources"
  default = {
    Project   = "qr-generator"
    ManagedBy = "terraform"
  }
}
