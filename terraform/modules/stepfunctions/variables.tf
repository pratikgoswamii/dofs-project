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

variable "validator_function_arn" {
  description = "ARN of the validator Lambda function"
  type        = string
}

variable "order_storage_function_arn" {
  description = "ARN of the order storage Lambda function"
  type        = string
}
