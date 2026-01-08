# This file configures where Terraform stores its state
terraform {
  backend "s3" {
    # S3 bucket for state storage
    bucket = "s3-vectors-url-embed-state-xd4a"
    key    = "s3-vectors-url-embed/terraform.tfstate"
    region = "us-east-1"
    
    # Enable encryption at rest
    encrypt = true
    
    # DynamoDB table for state locking
    dynamodb_table = "s3-vectors-url-embed-state-lock"
    
    # Optional: Enable versioning for state file history
    # versioning = true
  }
}




#aws s3 mb s3://s3-vectors-url-embed-state-xd4a --region us-east-1
#aws s3api put-bucket-versioning --bucket s3-vectors-url-embed-state-xd4a  \
#  --versioning-configuration Status=Enabled
#aws s3api put-bucket-encryption --bucket s3-vectors-url-embed-state-xd4a  \
#  --server-side-encryption-configuration \
#  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
#
#aws dynamodb create-table \
#  --table-name s3-vectors-url-embed-state-lock \
#  --attribute-definitions AttributeName=LockID,AttributeType=S \
#  --key-schema AttributeName=LockID,KeyType=HASH \
#  --billing-mode PAY_PER_REQUEST \
#  --region us-east-1


# ============================================================================
# S3 Backend (recommended for production and collaboration)
# ============================================================================

# 1. Created an S3 bucket for state storage
# 2. Created a DynamoDB table for state locking
# 3. Updated the bucket and table names in above config

# ============================================================================
# How to set up S3 backend (one-time setup):
# ============================================================================
# 1. Create S3 bucket:
#    aws s3 mb s3://your-terraform-state-bucket --region us-east-1
#    aws s3api put-bucket-versioning --bucket your-terraform-state-bucket \
#      --versioning-configuration Status=Enabled
#    aws s3api put-bucket-encryption --bucket your-terraform-state-bucket \
#      --server-side-encryption-configuration \
#      '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
#
# 2. Create DynamoDB table:
#    aws dynamodb create-table \
#      --table-name terraform-state-lock-etc \
#      --attribute-definitions AttributeName=LockID,AttributeType=S \
#      --key-schema AttributeName=LockID,KeyType=HASH \
#      --billing-mode PAY_PER_REQUEST \
#      --region us-east-1
#
# 3. Uncomment the backend block above and update bucket/table names
#
# 4. Run: terraform init -migrate-state
# ============================================================================