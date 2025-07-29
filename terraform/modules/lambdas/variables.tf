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

variable "orders_table_name" {
  description = "Name of the orders DynamoDB table"
  type        = string
}

variable "orders_table_arn" {
  description = "ARN of the orders DynamoDB table"
  type        = string
}

variable "failed_orders_table_name" {
  description = "Name of the failed orders DynamoDB table"
  type        = string
}

variable "failed_orders_table_arn" {
  description = "ARN of the failed orders DynamoDB table"
  type        = string
}

variable "order_queue_url" {
  description = "URL of the order SQS queue"
  type        = string
}

variable "order_queue_arn" {
  description = "ARN of the order SQS queue"
  type        = string
}

variable "order_dlq_arn" {
  description = "ARN of the order DLQ"
  type        = string
}

variable "step_function_arn" {
  description = "ARN of the Step Function"
  type        = string
}

variable "dlq_alert_sns_topic_arn" {
  description = "SNS topic ARN for DLQ alerts (optional)"
  type        = string
  default     = ""
}
