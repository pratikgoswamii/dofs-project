variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "dofs"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "api_handler_lambda_invoke_arn" {
  description = "ARN for invoking the API handler Lambda function"
  type        = string
}

variable "api_handler_lambda_function_name" {
  description = "Name of the API handler Lambda function"
  type        = string
}
