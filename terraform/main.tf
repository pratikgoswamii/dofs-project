# Main Terraform configuration for DOFS project
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}

# DynamoDB Module (must be created first)
module "dynamodb" {
  source = "./modules/dynamodb"
  
  project_name = var.project_name
  environment  = var.environment
}

# SQS Module
module "sqs" {
  source = "./modules/sqs"
  
  project_name        = var.project_name
  environment         = var.environment
  max_receive_count   = var.max_receive_count
  dlq_alarm_threshold = var.dlq_alarm_threshold
}

# Compute Module (combines lambdas and stepfunctions to resolve circular dependency)
module "compute" {
  source = "./modules/compute"
  
  project_name              = var.project_name
  environment               = var.environment
  orders_table_name         = module.dynamodb.orders_table_name
  orders_table_arn          = module.dynamodb.orders_table_arn
  failed_orders_table_name  = module.dynamodb.failed_orders_table_name
  failed_orders_table_arn   = module.dynamodb.failed_orders_table_arn
  order_queue_url           = module.sqs.order_queue_url
  order_queue_arn           = module.sqs.order_queue_arn
  order_dlq_arn             = module.sqs.order_dlq_arn
  
  depends_on = [module.dynamodb, module.sqs]
}

# API Gateway Module
module "api_gateway" {
  source = "./modules/api_gateway"
  
  project_name                     = var.project_name
  environment                      = var.environment
  api_handler_lambda_invoke_arn    = module.compute.api_handler_invoke_arn
  api_handler_lambda_function_name = module.compute.api_handler_function_name
  
  depends_on = [module.compute]
}

# CI/CD Module
module "cicd" {
  source = "./modules/cicd"
  
  project_name           = var.project_name
  environment            = var.environment
  aws_region             = var.aws_region
  source_repository_name = "dofs-project"
  source_branch_name     = "main"
  tags = {
    Project     = "DOFS"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
  
  depends_on = [module.api_gateway]
}


