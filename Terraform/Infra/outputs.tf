output "cognito_user_pool_id" {
  value       = module.cognito.user_pool_id
  description = "Cognito User Pool ID (use in frontend SDK)"
}

output "cognito_spa_client_id" {
  value       = module.cognito.spa_client_id
  description = "Cognito SPA Client ID (use in frontend SDK)"
}
