# CI/CD Pipeline for DOFS project using AWS CodePipeline

# S3 Bucket for CodePipeline artifacts
resource "aws_s3_bucket" "codepipeline_artifacts" {
  bucket = "${var.project_name}-codepipeline-artifacts-${var.environment}-${random_string.bucket_suffix.result}"

  tags = {
    Name        = "${var.project_name}-codepipeline-artifacts-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_s3_bucket_versioning" "codepipeline_artifacts_versioning" {
  bucket = aws_s3_bucket.codepipeline_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "codepipeline_artifacts_encryption" {
  bucket = aws_s3_bucket.codepipeline_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# IAM Role for CodePipeline
resource "aws_iam_role" "codepipeline_role" {
  name = "${var.project_name}-codepipeline-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-codepipeline-role-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM Policy for CodePipeline
resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "${var.project_name}-codepipeline-policy-${var.environment}"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketVersioning",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.codepipeline_artifacts.arn,
          "${aws_s3_bucket.codepipeline_artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = aws_codebuild_project.terraform_build.arn
      },
      {
        Effect = "Allow"
        Action = [
          "codecommit:GetBranch",
          "codecommit:GetCommit",
          "codecommit:GetRepository",
          "codecommit:ListBranches",
          "codecommit:ListRepositories"
        ]
        Resource = var.source_repository_arn
      }
    ]
  })
}

# IAM Role for CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "${var.project_name}-codebuild-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-codebuild-role-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM Policy for CodeBuild
resource "aws_iam_role_policy" "codebuild_policy" {
  name = "${var.project_name}-codebuild-policy-${var.environment}"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.codepipeline_artifacts.arn,
          "${aws_s3_bucket.codepipeline_artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          var.terraform_state_bucket_arn,
          "${var.terraform_state_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = var.terraform_state_lock_table_arn
      },
      {
        Effect = "Allow"
        Action = [
          "iam:*",
          "lambda:*",
          "apigateway:*",
          "dynamodb:*",
          "sqs:*",
          "states:*",
          "logs:*",
          "cloudwatch:*",
          "s3:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# CodeBuild Project
resource "aws_codebuild_project" "terraform_build" {
  name          = "${var.project_name}-terraform-build-${var.environment}"
  description   = "Build project for DOFS Terraform infrastructure"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                      = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type                       = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "TERRAFORM_VERSION"
      value = "1.5.0"
    }

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }

  tags = {
    Name        = "${var.project_name}-terraform-build-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# CodePipeline
resource "aws_codepipeline" "dofs_pipeline" {
  name     = "${var.project_name}-pipeline-${var.environment}"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        RepositoryName = var.source_repository_name
        BranchName     = var.source_branch_name
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.terraform_build.name
      }
    }
  }

  dynamic "stage" {
    for_each = var.enable_manual_approval ? [1] : []
    content {
      name = "ManualApproval"

      action {
        name     = "ManualApproval"
        category = "Approval"
        owner    = "AWS"
        provider = "Manual"
        version  = "1"

        configuration = {
          CustomData = "Please review the Terraform plan and approve deployment to ${var.environment}"
        }
      }
    }
  }

  tags = {
    Name        = "${var.project_name}-pipeline-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}
