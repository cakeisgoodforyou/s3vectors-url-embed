variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
  
  validation {
    condition     = can(regex("^(us|eu|ap|sa|ca|me|af)-(north|south|east|west|central|northeast|southeast)-[1-9]$", var.aws_region))
    error_message = "Must be a valid AWS region."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "owner" {
  description = "Owner/creator of the resources (for tagging)"
  type        = string
  default     = "ai-engineer"
}

# Bedrock Model Configuration
variable "orchestrator_model_id" {
  description = "Bedrock model ID for orchestrator agent"
  type        = string
  default     = "anthropic.claude-sonnet-4-20250514"
}

variable "ingestion_model_id" {
  description = "Bedrock model ID for ingestion agent"
  type        = string
  default     = "anthropic.claude-haiku-4-5-20251001"
}

variable "code_generator_model_id" {
  description = "Bedrock model ID for code generator agent"
  type        = string
  default     = "anthropic.claude-sonnet-4-20250514"
}

variable "test_executor_model_id" {
  description = "Bedrock model ID for test executor agent"
  type        = string
  default     = "anthropic.claude-haiku-4-5-20251001"
}

variable "embedding_model_id" {
  description = "Bedrock embedding model ID for Knowledge Base"
  type        = string
  default     = "amazon.titan-embed-text-v2:0"
}

# Lambda Configuration
variable "lambda_runtime" {
  description = "Python runtime version for Lambda functions"
  type        = string
  default     = "python3.12"
}

variable "lambda_architecture" {
  description = "Lambda architecture (x86_64 or arm64)"
  type        = string
  default     = "arm64"
  
  validation {
    condition     = contains(["x86_64", "arm64"], var.lambda_architecture)
    error_message = "Lambda architecture must be x86_64 or arm64."
  }
}

# Cost Optimization Settings
variable "cloudwatch_log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 7
}

variable "max_refinement_iterations" {
  description = "Maximum number of code refinement iterations to prevent infinite loops"
  type        = number
  default     = 5
  
  validation {
    condition     = var.max_refinement_iterations > 0 && var.max_refinement_iterations <= 10
    error_message = "Max refinement iterations must be between 1 and 10."
  }
}

# API Gateway Configuration
variable "api_throttle_rate_limit" {
  description = "API Gateway throttle rate limit (requests per second)"
  type        = number
  default     = 10
}

variable "api_throttle_burst_limit" {
  description = "API Gateway throttle burst limit"
  type        = number
  default     = 20
}

# Knowledge Base Configuration
variable "kb_chunking_strategy" {
  description = "Knowledge Base chunking strategy"
  type        = string
  default     = "FIXED_SIZE"
  
  validation {
    condition     = contains(["FIXED_SIZE", "NONE"], var.kb_chunking_strategy)
    error_message = "Must be FIXED_SIZE or NONE."
  }
}

variable "kb_chunk_size" {
  description = "Knowledge Base chunk size in tokens"
  type        = number
  default     = 300
  
  validation {
    condition     = var.kb_chunk_size >= 20 && var.kb_chunk_size <= 8192
    error_message = "Chunk size must be between 20 and 8192 tokens."
  }
}

variable "kb_chunk_overlap_percentage" {
  description = "Knowledge Base chunk overlap percentage"
  type        = number
  default     = 20
  
  validation {
    condition     = var.kb_chunk_overlap_percentage >= 0 && var.kb_chunk_overlap_percentage <= 99
    error_message = "Chunk overlap must be between 0 and 99 percent."
  }
}

# DynamoDB Configuration
variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode (PAY_PER_REQUEST or PROVISIONED)"
  type        = string
  default     = "PAY_PER_REQUEST"
  
  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.dynamodb_billing_mode)
    error_message = "Must be PAY_PER_REQUEST or PROVISIONED."
  }
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
