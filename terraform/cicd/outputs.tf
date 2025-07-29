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
  value       = aws_codebuild_project.terraform_build.name
}

output "codebuild_project_arn" {
  description = "ARN of the CodeBuild project"
  value       = aws_codebuild_project.terraform_build.arn
}

output "artifacts_bucket_name" {
  description = "Name of the S3 bucket for pipeline artifacts"
  value       = aws_s3_bucket.codepipeline_artifacts.bucket
}

output "artifacts_bucket_arn" {
  description = "ARN of the S3 bucket for pipeline artifacts"
  value       = aws_s3_bucket.codepipeline_artifacts.arn
}
