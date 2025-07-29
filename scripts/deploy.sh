#!/bin/bash

# DOFS Deployment Script
# This script packages Lambda functions and deploys the infrastructure

set -e

PROJECT_NAME="dofs"
ENVIRONMENT=${1:-dev}
AWS_REGION=${2:-ap-south-1}

echo "🚀 Starting DOFS deployment for environment: $ENVIRONMENT"

# Function to create Lambda deployment packages
create_lambda_package() {
    local lambda_dir=$1
    local lambda_name=$2
    
    echo "📦 Packaging Lambda function: $lambda_name"
    
    cd "$lambda_dir"
    
    # Remove existing zip file
    rm -f "${lambda_name}.zip"
    
    # Create zip package
    zip -r "${lambda_name}.zip" . -x "*.zip" "__pycache__/*" "*.pyc"
    
    echo "✅ Package created: ${lambda_dir}/${lambda_name}.zip"
    
    cd - > /dev/null
}

# Package all Lambda functions
echo "📦 Packaging Lambda functions..."

create_lambda_package "lambdas/api_handler" "api_handler"
create_lambda_package "lambdas/validator" "validator"
create_lambda_package "lambdas/order_storage" "order_storage"
create_lambda_package "lambdas/fulfill_order" "fulfill_order"
create_lambda_package "lambdas/dlq_processor" "dlq_processor"

echo "✅ All Lambda functions packaged successfully"

# Initialize Terraform
echo "🔧 Initializing Terraform..."
cd terraform
terraform init

# Validate Terraform configuration
echo "🔍 Validating Terraform configuration..."
terraform validate

# Plan deployment
echo "📋 Planning Terraform deployment..."
terraform plan -var="environment=$ENVIRONMENT" -var="aws_region=$AWS_REGION" -out=tfplan

# Apply deployment (with confirmation)
echo "🚀 Applying Terraform deployment..."
read -p "Do you want to apply the deployment? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    terraform apply tfplan
    echo "✅ Deployment completed successfully!"
    
    # Show outputs
    echo "📊 Deployment outputs:"
    terraform output
else
    echo "❌ Deployment cancelled"
    rm -f tfplan
    exit 1
fi

# Clean up
rm -f tfplan

echo "🎉 DOFS deployment completed for environment: $ENVIRONMENT"
