# IAM roles for CI/CD pipeline

data "aws_caller_identity" "current" {}

# CodePipeline service role
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
  tags = var.tags
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "${var.project_name}-codepipeline-policy-${var.environment}"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject*",
          "s3:GetBucket*",
          "s3:List*",
          "s3:PutObject*"
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
          "codebuild:StartBuild",
          "codebuild:BatchGetBuildBatches",
          "codebuild:StartBuildBatch",
          "codebuild:ListBuildBatches",
          "codebuild:BatchGetProjects"
        ]
        Resource = [aws_codebuild_project.dofs_build.arn]
      },
      {
        Effect = "Allow"
        Action = ["codestar-connections:UseConnection"]
        Resource = [aws_codestarconnections_connection.github_connection.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "codepipeline:GetPipeline",
          "codepipeline:GetPipelineState",
          "codepipeline:GetPipelineExecution",
          "codepipeline:ListPipelineExecutions",
          "codepipeline:ListActionTypes",
          "codepipeline:ListPipelines"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = [aws_iam_role.codebuild_role.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:DescribeKey",
          "kms:GenerateDataKey*",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:Decrypt"
        ]
        Resource = "*"
        Condition = {
          StringLikeIfExists = {
            "kms:ViaService" = [
              "s3.${var.aws_region}.amazonaws.com",
              "codestar-connections.${var.aws_region}.amazonaws.com"
            ]
          }
        }
      }
    ]
  })
}

# CodeBuild service role
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
  tags = var.tags
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "${var.project_name}-codebuild-policy-${var.environment}"
  role = aws_iam_role.codebuild_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # CloudWatch Logs permissions
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.project_name}-${var.environment}*:*",
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.project_name}-${var.environment}*:log-stream:*"
        ]
      },
      
      # S3 permissions
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject*",
          "s3:PutObject*",
          "s3:ListBucket*"
        ]
        Resource = [
          aws_s3_bucket.codepipeline_artifacts.arn,
          "${aws_s3_bucket.codepipeline_artifacts.arn}/*"
        ]
      },
      
      # CodePipeline permissions
      {
        Effect = "Allow"
        Action = [
          "codepipeline:GetPipeline",
          "codepipeline:GetPipelineState",
          "codepipeline:GetPipelineExecution"
        ]
        Resource = "*"
      },
      
      # CodeBuild permissions
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild",
          "codebuild:BatchGetBuildBatches",
          "codebuild:StartBuildBatch"
        ]
        Resource = [aws_codebuild_project.dofs_build.arn]
      },
      
      # CodeStar Connections
      {
        Effect = "Allow"
        Action = ["codestar-connections:UseConnection"]
        Resource = [aws_codestarconnections_connection.github_connection.arn]
      },
      
      # KMS permissions
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = ["*"]
      },
      
      # IAM permissions for CloudFormation
      {
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*"]
      },
      
      # CloudWatch metrics
      {
        Effect = "Allow"
        Action = ["cloudwatch:PutMetricData"]
        Resource = ["*"]
      },
      
      # Service-specific permissions (scoped down from original wildcards)
      {
        Effect = "Allow"
        Action = [
          # Lambda
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:ListVersionsByFunction",
          
          # API Gateway
          "apigateway:POST",
          "apigateway:GET",
          "apigateway:PUT",
          "apigateway:PATCH",
          "apigateway:DELETE",
          
          # DynamoDB
          "dynamodb:CreateTable",
          "dynamodb:UpdateTable",
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          
          # SQS
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes",
          
          # Step Functions
          "states:StartExecution",
          "states:DescribeExecution",
          "states:StopExecution"
        ]
        Resource = ["*"]
      },
      
      # Terraform state access
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.codepipeline_artifacts.arn,
          "${aws_s3_bucket.codepipeline_artifacts.arn}/*"
        ]
      },
      
      # ECR permissions for Docker images
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "*"
      }
    ]
  })
}