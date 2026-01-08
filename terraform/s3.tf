# S3 bucket for ingestion agent use in storing API docs
resource "aws_s3_bucket" "api_docs" {
  bucket = "${local.name_prefix}-api-docs"
  tags = merge(local.common_tags, {
    Purpose = "Store API docs to be synced with knowledge base"
  })
}
# Enable encryption on generated code bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "api_docs" {
  bucket = aws_s3_bucket.api_docs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
# Block public access on api docs bucket
resource "aws_s3_bucket_public_access_block" "api_docs" {
  bucket = aws_s3_bucket.api_docs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket for generated code artifacts
resource "aws_s3_bucket" "generated_code" {
  bucket = "${local.name_prefix}-generated-code"
  tags = merge(local.common_tags, {
    Purpose = "Store generated Python code and test results"
  })
}

# Enable encryption on generated code bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "generated_code" {
  bucket = aws_s3_bucket.generated_code.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle policy for generated code bucket (cost optimization)
resource "aws_s3_bucket_lifecycle_configuration" "generated_code" {
  bucket = aws_s3_bucket.generated_code.id
  rule {
    id     = "delete-old-code"
    status = "Enabled"
    filter {}
    expiration {
      days = 90
    }
  }
}

# Block public access on generated code bucket
resource "aws_s3_bucket_public_access_block" "generated_code" {
  bucket = aws_s3_bucket.generated_code.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
