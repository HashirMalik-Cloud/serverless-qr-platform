variable "project_prefix" {
  type = string
}

variable "ttl_attribute_name" {
  type    = string
  default = "expiryTime"
}

variable "tags" {
  type = map(string)
  default = {
    Project   = "qr-generator"
    ManagedBy = "terraform"
  }
}
