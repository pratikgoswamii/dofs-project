output "codepipeline_name" {
  description = "Name of the CodePipeline"
  value       = aws_codepipeline.dofs_pipeline.name
}

output "codepipeline_arn" {
  description = "ARN of the CodePipeline"
  value       = aws_codepipeline.dofs_pipeline.arn
}

output "codebuild_project_name" {
  description = "Name of the CodeBuild project"
  value       = aws_codebuild_project.dofs_build.name
}

output "github_repository" {
  description = "GitHub repository being used"
  value       = "${var.github_owner}/${var.github_repo}"
}

output "artifacts_bucket_name" {
  description = "Name of the S3 bucket for pipeline artifacts"
  value       = aws_s3_bucket.codepipeline_artifacts.bucket
}

output "github_connection_arn" {
  description = "CodeStar connection ARN for GitHub"
  value       = aws_codestarconnections_connection.github_connection.arn
}

output "github_connection_status" {
  description = "Status of GitHub connection"
  value       = aws_codestarconnections_connection.github_connection.connection_status
}
