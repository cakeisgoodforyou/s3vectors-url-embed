# Data Source - Connects S3 bucket to Knowledge Base. 
# Sync the knowledge base with this bucket to automatically ingest new vectors.

resource "aws_bedrockagent_data_source" "api_docs" {
  name              = "${local.name_prefix}-docs-source"
  knowledge_base_id = aws_bedrockagent_knowledge_base.api_docs.id
  
  data_source_configuration {
    type = "S3"
    
    s3_configuration {
      bucket_arn = aws_s3_bucket.api_docs.arn
      # Optional: Limit to specific prefix
      # inclusion_prefixes = ["docs/"]
    }
  }
  
  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = var.kb_chunking_strategy
      
      fixed_size_chunking_configuration {
        max_tokens         = var.kb_chunk_size
        overlap_percentage = var.kb_chunk_overlap_percentage
      }
    }
  }
  # Optional: Configure parsing
  # data_deletion_policy = "RETAIN" or "DELETE"
  depends_on = [
    aws_bedrockagent_knowledge_base.api_docs
  ]
}
