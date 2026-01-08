# Bedrock Knowledge Base with S3 Vector Buckets
resource "aws_s3vectors_vector_bucket" "s3_vectors_url_embed_vector_store" {
  vector_bucket_name = "${local.name_prefix}-vectors"
  tags = merge(local.common_tags, {
    Purpose = "Store vector embeddings for Knowledge Base"
  })
}

# ----------------------------
# Null resource to create the index via CLI
# ----------------------------
resource "null_resource" "create_vector_index" {
  depends_on = [aws_s3vectors_vector_bucket.s3_vectors_url_embed_vector_store]

  provisioner "local-exec" {
    command = <<EOT
      aws s3vectors create-index \
        --index-name ${local.name_prefix}-vectors-index \
        --vector-bucket-name ${aws_s3vectors_vector_bucket.s3_vectors_url_embed_vector_store.vector_bucket_name} \
        --dimension 256 \
        --distance-metric euclidean \
        --data-type float32 \
        --metadata-configuration '{"nonFilterableMetadataKeys":["AMAZON_BEDROCK_METADATA","AMAZON_BEDROCK_TEXT","x-amz-bedrock-kb-data-source-id","S3VECTORS-EMBED-SRC-LOCATION","S3VECTORS-EMBED-SRC-CONTENT"]}'
    EOT
  }
}

# resource "aws_s3vectors_index" "s3_vectors_url_embed_vectors_index" {
#   depends_on         = [null_resource.update_vector_metadata]
#   index_name         = "${local.name_prefix}-vectors-index"
#   vector_bucket_name = aws_s3vectors_vector_bucket.s3_vectors_url_embed_vector_store.vector_bucket_name
#   data_type          = "float32"
#   dimension          = 256
#   distance_metric    = "euclidean"
# }