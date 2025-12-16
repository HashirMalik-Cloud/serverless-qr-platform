// modules/lambdas/outputs.tf

# Generate QR
output "generate_qr_function_name" {
  description = "Name of the Generate QR Lambda function"
  value       = aws_lambda_function.generate_qr.function_name
}

output "generate_qr_function_arn" {
  description = "ARN of the Generate QR Lambda function"
  value       = aws_lambda_function.generate_qr.arn
}

# Redirect (scan) handler
output "redirect_function_name" {
  description = "Name of the Redirect (scan) Lambda function"
  value       = aws_lambda_function.redirect_lambda.function_name
}

output "redirect_function_arn" {
  description = "ARN of the Redirect (scan) Lambda function"
  value       = aws_lambda_function.redirect_lambda.arn
}

# Scan logger
output "scan_logger_function_name" {
  description = "Name of the Scan Logger Lambda function"
  value       = aws_lambda_function.scan_logger.function_name
}

output "scan_logger_function_arn" {
  description = "ARN of the Scan Logger Lambda function"
  value       = aws_lambda_function.scan_logger.arn
}

output "cleanup_lambda_name" {
  value = aws_lambda_function.cleanup.function_name
}

output "cleanup_lambda_arn" {
  value = aws_lambda_function.cleanup.arn
}

output "pdf_export_function_name" {
  value       = aws_lambda_function.pdf_export.function_name
  description = "PDF export Lambda function name"
}

output "pdf_export_function_arn" {
  value       = aws_lambda_function.pdf_export.arn
  description = "PDF export Lambda function ARN"
}
