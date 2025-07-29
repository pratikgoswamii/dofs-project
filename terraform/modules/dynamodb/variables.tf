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
