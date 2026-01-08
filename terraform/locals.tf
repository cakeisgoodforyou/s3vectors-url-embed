locals {
  project_name = "s3-vectors-url-embed"
  environment  = var.environment  
  name_prefix = "${local.project_name}-${var.environment}"
  # Naming convention: {project}-{environment}-{resource}

  common_tags = {
    Project     = local.project_name
    Environment = var.environment
  }
}