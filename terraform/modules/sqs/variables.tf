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

variable "max_receive_count" {
  description = "Maximum number of times a message can be received before being sent to DLQ"
  type        = number
  default     = 3
}

variable "dlq_alarm_threshold" {
  description = "Threshold for DLQ depth alarm"
  type        = number
  default     = 5
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for DLQ alerts (optional)"
  type        = string
  default     = ""
}
