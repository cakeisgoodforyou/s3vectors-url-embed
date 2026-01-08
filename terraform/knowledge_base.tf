resource "aws_bedrockagent_knowledge_base" "api_docs" {
    depends_on  = [null_resource.create_vector_index]
    name        = "${local.name_prefix}-kb"
    description = "API documentation knowledge base with S3 vector storage"
    role_arn    = aws_iam_role.knowledge_base.arn

  knowledge_base_configuration {
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/${var.embedding_model_id}"
      embedding_model_configuration {
        bedrock_embedding_model_configuration {
          dimensions          = 256
          embedding_data_type = "FLOAT32"
        }
      }
    }
    type = "VECTOR"
  }
  
  storage_configuration {
    type = "S3_VECTORS"
    s3_vectors_configuration {
      index_arn = "arn:aws:s3vectors:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:bucket/${local.name_prefix}-vectors/index/${local.name_prefix}-vectors-index"
      #index_arn = aws_s3vectors_index.s3_vectors_url_embed_vectors_index.index_arn
    }
  }
  
  tags = local.common_tags
}