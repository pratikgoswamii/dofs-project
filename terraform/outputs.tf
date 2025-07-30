# Outputs for DOFS project
output "api_gateway_url" {
  description = "API Gateway URL"
  value       = module.api_gateway.api_gateway_invoke_url
}

output "lambda_function_names" {
  description = "Names of Lambda functions"
  value       = {
    api_handler = module.compute.api_handler_function_name
    validator = module.compute.validator_function_name
    order_storage = module.compute.order_storage_function_name
    fulfillment = module.compute.fulfillment_function_name
  }
}

output "dynamodb_table_names" {
  description = "Names of DynamoDB tables"
  value       = {
    orders = module.dynamodb.orders_table_name
    failed_orders = module.dynamodb.failed_orders_table_name
  }
}

output "sqs_queue_urls" {
  description = "SQS queue URLs"
  value       = {
    order_queue = module.sqs.order_queue_url
    order_dlq = module.sqs.order_dlq_url
  }
}

output "step_function_arn" {
  description = "Step Function ARN"
  value       = module.compute.step_function_arn
}

output "cicd_info" {
  description = "CI/CD pipeline information"
  value       = {
    pipeline_name = module.cicd.codepipeline_name
    github_connection_arn = module.cicd.github_connection_arn
    github_connection_status = module.cicd.github_connection_status
  }
}
