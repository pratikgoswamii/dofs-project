# Backend configuration for Terraform state
terraform {
  backend "s3" {
    bucket         = "dofs-terraform-state-13012002"
    key            = "terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "dofs-terraform-locks"
  }
}
