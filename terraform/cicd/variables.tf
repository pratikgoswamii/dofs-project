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

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "source_repository_name" {
  description = "Name of the CodeCommit repository"
  type        = string
  default     = "dofs-project"
}

variable "source_repository_arn" {
  description = "ARN of the source repository"
  type        = string
}

variable "source_branch_name" {
  description = "Branch name to trigger the pipeline"
  type        = string
  default     = "main"
}

variable "terraform_state_bucket_arn" {
  description = "ARN of the S3 bucket for Terraform state"
  type        = string
}

variable "terraform_state_lock_table_arn" {
  description = "ARN of the DynamoDB table for Terraform state locking"
  type        = string
}

variable "enable_manual_approval" {
  description = "Enable manual approval stage in the pipeline"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "DOFS"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}
