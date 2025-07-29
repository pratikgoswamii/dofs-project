output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = aws_api_gateway_rest_api.dofs_api.id
}

output "api_gateway_execution_arn" {
  description = "Execution ARN of the API Gateway"
  value       = aws_api_gateway_rest_api.dofs_api.execution_arn
}

output "api_gateway_invoke_url" {
  description = "Invoke URL of the API Gateway"
  value       = aws_api_gateway_stage.dofs_api_stage.invoke_url
}

output "api_gateway_stage_name" {
  description = "Stage name of the API Gateway deployment"
  value       = aws_api_gateway_stage.dofs_api_stage.stage_name
}
