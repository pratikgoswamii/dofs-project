# CodePipeline for DOFS CI/CD
resource "aws_codepipeline" "dofs_pipeline" {
  name     = "${var.project_name}-pipeline"
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
      provider         = "S3"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        S3Bucket    = aws_s3_bucket.source_bucket.bucket
        S3ObjectKey = "source.zip"
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
        ProjectName = aws_codebuild_project.dofs_build.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CloudFormation"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ActionMode     = "CREATE_UPDATE"
        Capabilities   = "CAPABILITY_IAM"
        OutputFileName = "CreateStackOutput.json"
        StackName      = "${var.project_name}-stack"
        TemplatePath   = "build_output::packaged-template.yaml"
        RoleArn        = aws_iam_role.cloudformation_role.arn
      }
    }
  }

  tags = var.tags
}

# S3 bucket for CodePipeline artifacts
resource "aws_s3_bucket" "codepipeline_artifacts" {
  bucket = "${var.project_name}-codepipeline-artifacts"
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "codepipeline_artifacts_versioning" {
  bucket = aws_s3_bucket.codepipeline_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket for source code
resource "aws_s3_bucket" "source_bucket" {
  bucket = "${var.project_name}-source"
  tags   = var.tags
}
