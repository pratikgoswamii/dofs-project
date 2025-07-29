# Variables for DOFS project
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "dofs"
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

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "DOFS"
    ManagedBy   = "Terraform"
  }
}
