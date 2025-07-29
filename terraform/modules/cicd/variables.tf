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

variable "source_branch_name" {
  description = "Branch name to trigger the pipeline"
  type        = string
  default     = "main"
}

variable "github_owner" {
  description = "GitHub repository owner/organization"
  type        = string
  default     = "pratikgoswamii"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "dofs-project"
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
