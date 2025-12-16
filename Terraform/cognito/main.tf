###############################################
# COGNITO USER POOL
###############################################
resource "aws_cognito_user_pool" "this" {
  name = "${var.project_prefix}-user-pool"

  # Password policy
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }

  # Auto-verify email
  auto_verified_attributes = ["email"]

  # Standard attributes
  schema {
    attribute_data_type = "String"
    name                = "email"
    required            = true
  }

  schema {
    attribute_data_type = "String"
    name                = "name"
    required            = false
  }

  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  tags = var.tags
}

###############################################
# USER POOL CLIENT (SPA / FRONTEND)
# - generate_secret = false (SPA)
# - keep explicit SRP + refresh flows so existing frontend code works
###############################################
resource "aws_cognito_user_pool_client" "spa_client" {
  name         = "${var.project_prefix}-spa-client"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret = false

  # OAuth settings (kept but Hosted UI domain is removed; harmless to keep)
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = var.allowed_oauth_flows
  allowed_oauth_scopes                 = var.allowed_oauth_scopes

  # Redirect URLs (kept so client config remains compatible if you later use OAuth)
  callback_urls = var.callback_urls
  logout_urls   = var.logout_urls

  # Authentication flows for direct SDK/SRP usage
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  # Token lifetimes
  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 30

  prevent_user_existence_errors = "ENABLED"

  depends_on = [aws_cognito_user_pool.this]
}
