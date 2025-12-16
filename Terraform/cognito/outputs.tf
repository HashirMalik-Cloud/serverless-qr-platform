output "user_pool_id" {
  value       = aws_cognito_user_pool.this.id
  description = "Cognito User Pool ID"
}

output "spa_client_id" {
  value       = aws_cognito_user_pool_client.spa_client.id
  description = "Cognito SPA Client ID (use this in your frontend SDK config)"
}

output "user_pool_arn" {
  value       = aws_cognito_user_pool.this.arn
  description = "Cognito User Pool ARN"
}
