# Account Information
output "aws_account_id" {
  description = "AWS Account ID where resources are deployed"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS Region where resources are deployed"
  value       = data.aws_region.current.name
}

# S3 Buckets
output "generated_code_bucket_name" {
  description = "Name of S3 bucket for generated code"
  value       = aws_s3_bucket.generated_code.id
}

output "generated_code_bucket_arn" {
  description = "ARN of S3 bucket for generated code"
  value       = aws_s3_bucket.generated_code.arn
}

# Project Metadata
output "project_name" {
  description = "Project name"
  value       = local.project_name
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "name_prefix" {
  description = "Common name prefix used for resources"
  value       = local.name_prefix
}

# Configuration Values
output "lambda_runtime" {
  description = "Lambda runtime version"
  value       = var.lambda_runtime
}

output "lambda_architecture" {
  description = "Lambda architecture"
  value       = var.lambda_architecture
}

output "max_refinement_iterations" {
  description = "Maximum number of code refinement iterations"
  value       = var.max_refinement_iterations
}

output "fetch_docs_lambda_name" {
  description = "Name of lambda function to fetch docs for ingestion to bedrock KB"
  value       = aws_lambda_function.fetch_docs.function_name
}

