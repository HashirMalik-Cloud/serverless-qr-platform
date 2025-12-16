############################################
# modules/api_gateway/main.tf — Fixed CORS + Import-safe Authorizer
############################################

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  safe_generate_arn = var.lambda_generate_qr_arn != null ? trimspace(var.lambda_generate_qr_arn) : ""
  safe_get_arn      = var.lambda_get_qr_arn != null ? trimspace(var.lambda_get_qr_arn) : ""
  safe_redirect_arn = var.lambda_redirect_arn != null ? trimspace(var.lambda_redirect_arn) : ""
  safe_pdf_arn      = var.lambda_pdf_arn != null ? trimspace(var.lambda_pdf_arn) : ""

  get_qr_lambda = length(local.safe_get_arn) > 0 ? local.safe_get_arn : local.safe_generate_arn

  # For API Gateway integration_response values must be quoted string literals
  cors_allow_origin  = "'*'"
  cors_allow_headers = "'content-type,authorization,*'"
  cors_allow_methods = "'GET,POST,DELETE,OPTIONS'"

  # static keys for for_each so terraform plan is stable
  cors_static = {
    root  = {}
    qr    = {}
    qr_id = var.enable_get_qr     ? {} : null
    scan  = var.enable_redirect   ? {} : null
    pdf   = var.enable_pdf        ? {} : null
  }

  cors_targets = { for k, v in local.cors_static : k => v if v != null }

  # choose authorizer id: if user provided an import id use that, else use created resource (if created)
  authorizer_id = var.import_api_authorizer_id != "" ? var.import_api_authorizer_id : (
    var.enable_cognito ? (
      length(aws_api_gateway_authorizer.cognito_auth) > 0 ? aws_api_gateway_authorizer.cognito_auth[0].id : ""
    ) : ""
  )
}

############################################
# REST API
############################################
resource "aws_api_gateway_rest_api" "this" {
  name        = "${var.project_prefix}-rest-api"
  description = "REST API for QR project"
  tags        = var.tags
}

############################################
# Optional Cognito authorizer (create only if not importing and enabled)
# note: uses count so address is aws_api_gateway_authorizer.cognito_auth[0]
############################################
resource "aws_api_gateway_authorizer" "cognito_auth" {
  count       = (var.enable_cognito && var.import_api_authorizer_id == "") ? 1 : 0
  name        = "${var.project_prefix}-cognito-authorizer"
  rest_api_id = aws_api_gateway_rest_api.this.id
  type        = "COGNITO_USER_POOLS"

  provider_arns = [
    "arn:aws:cognito-idp:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:userpool/${var.cognito_user_pool_id}"
  ]

  identity_source = "method.request.header.Authorization"
}

############################################
# Resources
############################################
resource "aws_api_gateway_resource" "qr" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "qr"
}

resource "aws_api_gateway_resource" "qr_id" {
  count       = var.enable_get_qr ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.qr.id
  path_part   = "{id}"
}

resource "aws_api_gateway_resource" "scan" {
  count       = var.enable_redirect ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "scan"
}

resource "aws_api_gateway_resource" "pdf" {
  count       = var.enable_pdf ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "pdf"
}

############################################
# CORS OPTIONS (MOCK) + Integration responses
############################################
resource "aws_api_gateway_method" "options" {
  for_each    = local.cors_targets
  rest_api_id = aws_api_gateway_rest_api.this.id

  resource_id = (
    each.key == "root"   ? aws_api_gateway_rest_api.this.root_resource_id :
    each.key == "qr"     ? aws_api_gateway_resource.qr.id :
    each.key == "qr_id"  ? aws_api_gateway_resource.qr_id[0].id :
    each.key == "scan"   ? aws_api_gateway_resource.scan[0].id :
                          aws_api_gateway_resource.pdf[0].id
  )

  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_mock" {
  for_each    = local.cors_targets
  rest_api_id = aws_api_gateway_rest_api.this.id

  resource_id = aws_api_gateway_method.options[each.key].resource_id
  http_method = aws_api_gateway_method.options[each.key].http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_response" {
  for_each    = local.cors_targets
  rest_api_id = aws_api_gateway_rest_api.this.id

  resource_id = aws_api_gateway_method.options[each.key].resource_id
  http_method = aws_api_gateway_method.options[each.key].http_method
  status_code = "200"

  response_models = { "application/json" = "Empty" }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

resource "aws_api_gateway_integration_response" "options_integration_response" {
  for_each    = local.cors_targets
  rest_api_id = aws_api_gateway_rest_api.this.id

  resource_id = aws_api_gateway_method.options[each.key].resource_id
  http_method = aws_api_gateway_method.options[each.key].http_method
  status_code = aws_api_gateway_method_response.options_response[each.key].status_code

  response_templates = { "application/json" = "" }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = local.cors_allow_origin
    "method.response.header.Access-Control-Allow-Headers" = local.cors_allow_headers
    "method.response.header.Access-Control-Allow-Methods" = local.cors_allow_methods
  }
}

############################################
# Main methods (POST/GET/DELETE) — every METHOD has an integration now
# IMPORTANT: For AWS_PROXY the Lambda MUST return Access-Control-Allow-* headers
############################################

############################################
# POST /qr -> Lambda (AWS_PROXY) — Cognito Disabled
############################################
resource "aws_api_gateway_method" "post_qr" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.qr.id
  http_method   = "POST"
  authorization = "NONE"     # <— FIXED: removed Cognito
  authorizer_id = null       # <— FIXED
}

resource "aws_api_gateway_method_response" "post_qr_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.qr.id
  http_method = aws_api_gateway_method.post_qr.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }

  response_models = { "application/json" = "Empty" }
}

resource "aws_api_gateway_integration" "post_qr_integration" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.qr.id
  http_method             = aws_api_gateway_method.post_qr.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"

  uri = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${local.safe_generate_arn}/invocations"

  passthrough_behavior = "WHEN_NO_MATCH"
}

# DELETE /qr -> safe MOCK integration so deployment won't fail (frontend can still call)
resource "aws_api_gateway_method" "delete_qr" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.qr.id
  http_method   = "DELETE"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "delete_qr_mock_integration" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.qr.id
  http_method = aws_api_gateway_method.delete_qr.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "delete_qr_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.qr.id
  http_method = aws_api_gateway_method.delete_qr.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = { "application/json" = "Empty" }
}

resource "aws_api_gateway_integration_response" "delete_qr_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.qr.id
  http_method = aws_api_gateway_method.delete_qr.http_method
  status_code = aws_api_gateway_method_response.delete_qr_200.status_code

  response_templates = { "application/json" = "" }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = local.cors_allow_origin
  }
}

# GET /qr/{id} -> Lambda (optional)
resource "aws_api_gateway_method" "get_qr" {
  count        = var.enable_get_qr ? 1 : 0
  rest_api_id  = aws_api_gateway_rest_api.this.id
  resource_id  = aws_api_gateway_resource.qr_id[0].id
  http_method  = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_qr_integration" {
  count                   = var.enable_get_qr ? 1 : 0
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.qr_id[0].id
  http_method             = aws_api_gateway_method.get_qr[0].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${local.get_qr_lambda}/invocations"
}

# GET /scan -> Lambda (optional)
resource "aws_api_gateway_method" "get_scan" {
  count        = var.enable_redirect ? 1 : 0
  rest_api_id  = aws_api_gateway_rest_api.this.id
  resource_id  = aws_api_gateway_resource.scan[0].id
  http_method  = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "scan_integration" {
  count                   = var.enable_redirect ? 1 : 0
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.scan[0].id
  http_method             = aws_api_gateway_method.get_scan[0].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${local.safe_redirect_arn}/invocations"
}

# GET /pdf -> Lambda (optional)
resource "aws_api_gateway_method" "pdf_get" {
  count       = var.enable_pdf ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.pdf[0].id
  http_method = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "pdf_get_integration" {
  count                   = var.enable_pdf ? 1 : 0
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.pdf[0].id
  http_method             = aws_api_gateway_method.pdf_get[0].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${local.safe_pdf_arn}/invocations"
}

############################################
# Deployment & Stage
############################################
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    # change this to force a new deployment when terraform sees changes
    redeploy = timestamp()
  }

  lifecycle {
    create_before_destroy = true
  }

  # ensure integrations and mocks exist before creating deployment
  depends_on = [
    aws_api_gateway_integration.options_mock,
    aws_api_gateway_integration.post_qr_integration,
    aws_api_gateway_integration.get_qr_integration,
    aws_api_gateway_integration.scan_integration,
    aws_api_gateway_integration.pdf_get_integration,
    aws_api_gateway_integration.delete_qr_mock_integration,
    aws_api_gateway_integration_response.options_integration_response,
    aws_api_gateway_integration_response.delete_qr_integration_response
  ]
}

resource "aws_api_gateway_stage" "prod" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = "prod"
}

############################################
# Lambda permissions (API Gateway -> Lambda)
############################################
resource "aws_lambda_permission" "invoke_generate_qr" {
  count = length(local.safe_generate_arn) > 0 ? 1 : 0

  statement_id  = "AllowAPIGatewayInvokeGenerate"
  action        = "lambda:InvokeFunction"
  function_name = local.safe_generate_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

resource "aws_lambda_permission" "invoke_get_qr" {
  count = var.enable_get_qr ? 1 : 0

  statement_id  = "AllowAPIGatewayInvokeGet"
  action        = "lambda:InvokeFunction"
  function_name = local.get_qr_lambda
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

resource "aws_lambda_permission" "invoke_redirect" {
  count = var.enable_redirect ? 1 : 0

  statement_id  = "AllowAPIGatewayInvokeRedirect"
  action        = "lambda:InvokeFunction"
  function_name = local.safe_redirect_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

resource "aws_lambda_permission" "invoke_pdf" {
  count = var.enable_pdf ? 1 : 0

  statement_id  = "AllowAPIGatewayInvokePdf"
  action        = "lambda:InvokeFunction"
  function_name = local.safe_pdf_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

############################################
# Output
############################################
output "invoke_url" {
  value = aws_api_gateway_stage.prod.invoke_url
}
