##################################################
# modules/lambdas/main.tf
# Lambdas: generate, redirect, scan_logger, cleanup, pdf_export
##################################################

############## DATA SOURCES ######################
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

##################################################
# Shared IAM Role for Generate + Get Lambdas
##################################################
resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_s3_full" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_full" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

##################################################
# Fine-grained Inline Policy (shared)
##################################################
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_prefix}-lambda-inline-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:PutObject", "s3:GetObject"],
        Resource = "arn:aws:s3:::${var.s3_bucket_images}/*"
      },
      {
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem"
        ],
        Resource = "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.dynamodb_table}"
      },
      {
        Effect   = "Allow",
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Resource = "*"
      }
    ]
  })
}

##################################################
# Lambda Function: Generate QR
##################################################
resource "aws_lambda_function" "generate_qr" {
  function_name = "${var.project_prefix}-generate-qr"
  runtime       = "python3.11"
  handler       = "generate.lambda_handler"
  role          = aws_iam_role.lambda_exec.arn

  filename         = "${path.module}/generate_qr/generate_qr.zip"
  source_code_hash = filebase64sha256("${path.module}/generate_qr/generate_qr.zip")

  timeout     = 15
  memory_size = 256

  environment {
    variables = {
      IMAGES_BUCKET = var.s3_bucket_images
      TABLE_NAME    = var.dynamodb_table
    }
  }

  tags = var.tags
}

##################################################
# Redirect Lambda (scan endpoint)
##################################################
resource "aws_iam_role" "lambda_redirect_role" {
  name = "${var.project_prefix}-redirect-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_redirect_policy" {
  role = aws_iam_role.lambda_redirect_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["dynamodb:GetItem", "dynamodb:UpdateItem"],
        Resource = "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.dynamodb_table}"
      },
      {
        Effect   = "Allow",
        Action   = ["logs:*"],
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "redirect_lambda" {
  function_name = "${var.project_prefix}-redirect-handler"
  role          = aws_iam_role.lambda_redirect_role.arn
  runtime       = "python3.12"
  handler       = "lambda_redirect_handler.lambda_handler"

  filename         = "${path.module}/redirect_lambda/lambda_redirect_handler.zip"
  source_code_hash = filebase64sha256("${path.module}/redirect_lambda/lambda_redirect_handler.zip")

  timeout     = 10
  memory_size = 128

  environment {
    variables = merge(
      var.redirect_env_vars,
      {
        DDB_TABLE             = var.dynamodb_table
        SCAN_LOGGER_FUNCTION = aws_lambda_function.scan_logger.function_name
      }
    )
  }

  tags = var.tags
}

##################################################
# Scan Logger Lambda
##################################################
resource "aws_iam_role" "lambda_logger_role" {
  name = "${var.project_prefix}-scan-logger-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_logger_policy" {
  name = "${var.project_prefix}-scan-logger-inline-policy"
  role = aws_iam_role.lambda_logger_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["s3:PutObject", "s3:PutObjectAcl", "s3:ListBucket"],
        Resource = [
          "arn:aws:s3:::${var.scan_logs_bucket_name}",
          "arn:aws:s3:::${var.scan_logs_bucket_name}/*"
        ]
      },
      {
        Effect   = "Allow",
        Action   = ["logs:*"],
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "scan_logger" {
  function_name = "${var.project_prefix}-scan-logger"
  runtime       = "python3.12"
  handler       = "scan_logger.lambda_handler"
  role          = aws_iam_role.lambda_logger_role.arn

  filename         = "${path.module}/scan_logger/scan_logger.zip"
  source_code_hash = filebase64sha256("${path.module}/scan_logger/scan_logger.zip")

  timeout     = 10
  memory_size = 128

  environment {
    variables = {
      LOG_BUCKET = var.scan_logs_bucket_name
    }
  }

  tags = var.tags
}

##################################################
# Allow redirect Lambda → call scan logger
##################################################
resource "aws_iam_role_policy" "redirect_invoke_logger_policy" {
  name = "${var.project_prefix}-redirect-invoke-logger"
  role = aws_iam_role.lambda_redirect_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["lambda:InvokeFunction"],
      Resource = aws_lambda_function.scan_logger.arn
    }]
  })
}

##################################################
# Cleanup Lambda (QR expiry)
##################################################
locals {
  cleanup_lambda_name = "${var.project_prefix}-cleanup-lambda"
}

resource "aws_iam_role" "cleanup_lambda_role" {
  name = "${local.cleanup_lambda_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "cleanup_policy" {
  name = "${local.cleanup_lambda_name}-policy"
  role = aws_iam_role.cleanup_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["dynamodb:Scan", "dynamodb:DeleteItem"],
        Resource = "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.dynamodb_table}"
      },
      {
        Effect   = "Allow",
        Action   = ["s3:DeleteObject"],
        Resource = [
          "arn:aws:s3:::${var.images_bucket}/*",
          "arn:aws:s3:::${var.pdf_bucket}/*"
        ]
      },
      {
        Effect   = "Allow",
        Action   = ["logs:*"],
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "cleanup" {
  filename         = "${path.module}/cleanup_lambda/cleanup.zip"
  function_name    = local.cleanup_lambda_name
  role             = aws_iam_role.cleanup_lambda_role.arn
  handler          = "cleanup.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  source_code_hash = filebase64sha256("${path.module}/cleanup_lambda/cleanup.zip")

  environment {
    variables = {
      TABLE_NAME    = var.dynamodb_table
      IMAGES_BUCKET = var.images_bucket
      PDF_BUCKET    = var.pdf_bucket
    }
  }

  tags = var.tags
}

resource "aws_cloudwatch_event_rule" "cleanup_schedule" {
  name                = "${local.cleanup_lambda_name}-schedule"
  description         = "Daily cleanup of expired QR codes"
  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "cleanup_target" {
  rule      = aws_cloudwatch_event_rule.cleanup_schedule.name
  target_id = "cleanup-lambda"
  arn       = aws_lambda_function.cleanup.arn
}

resource "aws_lambda_permission" "cleanup_allow_eventbridge" {
  statement_id  = "AllowCleanupExecution"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cleanup.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cleanup_schedule.arn
}

##################################################
# PDF Export Lambda
##################################################
resource "aws_iam_role" "pdf_lambda_role" {
  name = "${var.project_prefix}-pdf-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "pdf_lambda_policy" {
  name = "${var.project_prefix}-pdf-lambda-policy"
  role = aws_iam_role.pdf_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid     = "DynamoDBRead",
        Effect  = "Allow",
        Action  = ["dynamodb:GetItem"],
        Resource = "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.dynamodb_table}"
      },
      {
        Sid     = "S3ReadImages",
        Effect  = "Allow",
        Action  = ["s3:GetObject"],
        Resource = "arn:aws:s3:::${var.images_bucket}/*"
      },
      {
        Sid     = "S3WritePDFs",
        Effect  = "Allow",
        Action  = ["s3:PutObject"],
        Resource = "arn:aws:s3:::${var.pdf_bucket}/*"
      },
      {
        Sid     = "Logs",
        Effect  = "Allow",
        Action  = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "pdf_export" {
  function_name = "${var.project_prefix}-pdf-export"
  runtime       = "python3.12"
  handler       = "pdf_export.lambda_handler"
  role          = aws_iam_role.pdf_lambda_role.arn

  filename         = "${path.module}/pdf_export/pdf_export.zip"
  source_code_hash = filebase64sha256("${path.module}/pdf_export/pdf_export.zip")

  timeout     = 30
  memory_size = 512

  environment {
    variables = {
      TABLE_NAME    = var.dynamodb_table
      IMAGES_BUCKET = var.images_bucket
      PDF_BUCKET    = var.pdf_bucket
    }
  }

  tags = var.tags
}

##################################################
# Allow API Gateway to invoke PDF Lambda
##################################################
resource "aws_lambda_permission" "allow_apigw_invoke_pdf" {
  count = var.api_gateway_execution_arn != null ? 1 : 0

  statement_id  = "AllowAPIGatewayInvokePDF"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pdf_export.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = var.api_gateway_execution_arn
}
