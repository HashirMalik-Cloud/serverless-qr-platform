output "rest_api_id" {
  value = aws_api_gateway_rest_api.this.id
}

output "rest_api_execution_arn" {
  value = aws_api_gateway_rest_api.this.execution_arn
}

output "rest_api_invoke_url" {
  value = "https://${aws_api_gateway_rest_api.this.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.prod.stage_name}"
}
