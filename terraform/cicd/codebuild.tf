# CodeBuild project for DOFS
resource "aws_codebuild_project" "dofs_build" {
  name          = "${var.project_name}-build"
  description   = "Build project for DOFS application"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                      = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type                       = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }

  tags = var.tags
}
