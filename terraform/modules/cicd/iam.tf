# -------------------------------
# CodePipeline IAM Role & Policy
# -------------------------------
resource "aws_iam_role" "codepipeline_role" {
  name = "${var.project_name}-codepipeline-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "codepipeline.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "${var.project_name}-codepipeline-policy-${var.environment}"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Access S3 buckets for artifacts
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = [
          aws_s3_bucket.codepipeline_artifacts.arn,
          "${aws_s3_bucket.codepipeline_artifacts.arn}/*"
        ]
      },
      # Start CodeBuild projects
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild",
          "codebuild:BatchGetBuildBatches"
        ]
        Resource = [
          aws_codebuild_project.dofs_build.arn
        ]
      },
      # Access CodeStar connection
      {
        Effect = "Allow"
        Action = [
          "codestar-connections:UseConnection",
          "codestar-connections:GetConnection"
        ]
        Resource = aws_codestarconnections_connection.github_connection.arn
      },
      # KMS for artifact encryption/decryption
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

# ----------------------------
# CodeBuild IAM Role & Policy
# ----------------------------
resource "aws_iam_role" "codebuild_role" {
  name = "${var.project_name}-codebuild-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "${var.project_name}-codebuild-policy-${var.environment}"
  role = aws_iam_role.codebuild_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # CloudWatch Logs access
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      # Access S3 for artifacts
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
      # CloudWatch permissions for metric alarm access
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricData",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:ListTagsForResource"
        ]
        Resource = "*"
      },
      # CodeBuild project info (for reading own project)
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetProjects"
        ]
        Resource = "arn:aws:codebuild:${var.aws_region}:${data.aws_caller_identity.current.account_id}:project/${var.project_name}-build-${var.environment}"
      },
      # CodeStar connections permissions
      {
        Effect = "Allow"
        Action = [
          "codestar-connections:UseConnection",
          "codestar-connections:GetConnection",
          "codestar-connections:ListTagsForResource"
        ]
        Resource = aws_codestarconnections_connection.github_connection.arn
      },
      # General permissions for deployment targets (adjust as needed)
      {
        Effect = "Allow"
        Action = [
          "lambda:*",
          "apigateway:*",
          "dynamodb:*",
          "sqs:*",
          "states:*",
          "iam:*",
          "logs:*",
          "s3:*"
        ]
        Resource = "*"
      }
    ]
  })
}