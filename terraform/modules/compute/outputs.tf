# Lambda Function Outputs
output "api_handler_function_name" {
  description = "Name of the API handler Lambda function"
  value       = aws_lambda_function.api_handler.function_name
}

output "api_handler_function_arn" {
  description = "ARN of the API handler Lambda function"
  value       = aws_lambda_function.api_handler.arn
}

output "api_handler_invoke_arn" {
  description = "Invoke ARN of the API handler Lambda function"
  value       = aws_lambda_function.api_handler.invoke_arn
}

output "validator_function_name" {
  description = "Name of the validator Lambda function"
  value       = aws_lambda_function.validator.function_name
}

output "validator_function_arn" {
  description = "ARN of the validator Lambda function"
  value       = aws_lambda_function.validator.arn
}

output "order_storage_function_name" {
  description = "Name of the order storage Lambda function"
  value       = aws_lambda_function.order_storage.function_name
}

output "order_storage_function_arn" {
  description = "ARN of the order storage Lambda function"
  value       = aws_lambda_function.order_storage.arn
}

output "fulfillment_function_name" {
  description = "Name of the fulfillment Lambda function"
  value       = aws_lambda_function.fulfillment.function_name
}

output "dlq_processor_function_name" {
  description = "Name of the DLQ processor Lambda function"
  value       = aws_lambda_function.dlq_processor.function_name
}

output "fulfillment_function_arn" {
  description = "ARN of the fulfillment Lambda function"
  value       = aws_lambda_function.fulfillment.arn
}

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution_role.arn
}

# Step Function Outputs
output "step_function_arn" {
  description = "ARN of the Step Function state machine"
  value       = aws_sfn_state_machine.order_processing.arn
}

output "step_function_name" {
  description = "Name of the Step Function state machine"
  value       = aws_sfn_state_machine.order_processing.name
}

output "step_function_role_arn" {
  description = "ARN of the Step Function execution role"
  value       = aws_iam_role.step_function_role.arn
}
