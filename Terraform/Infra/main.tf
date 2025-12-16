##################################################
# Root Terraform - infra/main.tf (FIXED, SAFE)
##################################################

########################################
# Modules
########################################

##############
# 1) DynamoDB
##############
module "dynamodb" {
  source         = "./modules/dynamodb"
  project_prefix = "hashir-qr"

  tags = {
    Project   = "qr-generator"
    ManagedBy = "terraform"
  }
}

##############
# 2) S3 Buckets
##############

## Images Bucket
module "s3_images" {
  source            = "./modules/s3_bucket"
  project_prefix    = "hashir-qr"
  name_suffix       = "images"
  enable_versioning = true
  encryption_type   = "AES256"

  tags = {
    Project   = "qr-generator"
    ManagedBy = "terraform"
  }
}

## PDFs Bucket
module "s3_pdfs" {
  source            = "./modules/s3_bucket"
  project_prefix    = "hashir-qr"
  name_suffix       = "pdfs"
  enable_versioning = false
  encryption_type   = "AES256"

  tags = {
    Project   = "qr-generator"
    ManagedBy = "terraform"
  }
}

## Logs Bucket
module "s3_logs" {
  source            = "./modules/s3_bucket"
  project_prefix    = "hashir-qr"
  name_suffix       = "logs"
  enable_versioning = false
  encryption_type   = "AES256"

  tags = {
    Project   = "qr-generator"
    ManagedBy = "terraform"
  }
}

##############
# 3) Cognito
##############
module "cognito" {
  source               = "./modules/cognito"
  project_prefix       = "hashir-qr"
  callback_urls        = var.callback_urls
  logout_urls          = var.logout_urls
  cognito_domain_prefix = var.cognito_domain_prefix
  tags                 = var.tags
}

#############################
# 4) Lambda Module
#############################
module "lambdas" {
  source               = "./modules/lambdas"
  project_prefix       = "hashir-qr"

  dynamodb_table       = module.dynamodb.table_name
  s3_bucket_images     = module.s3_images.bucket_name
  scan_logs_bucket_name = module.s3_logs.bucket_name
  pdf_bucket           = module.s3_pdfs.bucket_name
  images_bucket        = module.s3_images.bucket_name

  redirect_env_vars = {}
  tags              = {
    Project   = "qr-generator"
    ManagedBy = "terraform"
  }
}

#############################
# 5) API Gateway Module (FIXED)
#############################
module "api_gateway" {
  source              = "./modules/api_gateway"
  project_prefix      = "hashir-qr"

  cognito_user_pool_id = module.cognito.user_pool_id

  lambda_generate_qr_arn = module.lambdas.generate_qr_function_arn
  lambda_get_qr_arn      = module.lambdas.generate_qr_function_arn
  lambda_redirect_arn    = module.lambdas.redirect_function_arn
  lambda_pdf_arn         = module.lambdas.pdf_export_function_arn

  enable_pdf      = true
  enable_cognito  = true
  enable_get_qr   = true
  enable_redirect = true

  tags = {
    Project   = "qr-generator"
    ManagedBy = "terraform"
  }
}

#############################
# 6) Glue + Athena
#############################
module "glue" {
  source               = "./modules/glue"
  project_prefix       = "hashir-qr"
  scan_logs_bucket_name = module.s3_logs.bucket_name
  logs_prefix          = "logs/"
  athena_results_prefix = "athena-results/"

  tags = {
    Project   = "qr-generator"
    ManagedBy = "terraform"
  }
}

########################################
# Outputs
########################################

## S3
output "images_bucket_name" { value = module.s3_images.bucket_name }
output "pdfs_bucket_name"   { value = module.s3_pdfs.bucket_name }
output "logs_bucket_name"   { value = module.s3_logs.bucket_name }

## DynamoDB
output "dynamodb_table_name" { value = module.dynamodb.table_name }

## Lambdas
output "generate_qr_lambda_name" { value = module.lambdas.generate_qr_function_name }
output "generate_qr_lambda_arn"  { value = module.lambdas.generate_qr_function_arn }
output "redirect_lambda_name"    { value = module.lambdas.redirect_function_name }
output "redirect_lambda_arn"     { value = module.lambdas.redirect_function_arn }
output "scan_logger_lambda_name" { value = module.lambdas.scan_logger_function_name }

## API Gateway
output "api_rest_id"   { value = module.api_gateway.rest_api_id }
output "api_invoke_url" { value = module.api_gateway.invoke_url }

## Glue & Athena
output "glue_database_name"     { value = module.glue.glue_database_name }
output "glue_crawler_name"      { value = module.glue.glue_crawler_name }
output "athena_workgroup_name"  { value = module.glue.athena_workgroup_name }
output "athena_results_s3"      { value = module.glue.athena_results_s3 }
