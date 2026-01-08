# Trust policy that allows Bedrock to assume IAM role created below
data "aws_iam_policy_document" "kb_trust" {
  statement {
    effect = "Allow"
    
    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }
    
    actions = ["sts:AssumeRole"]
    
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:bedrock:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:knowledge-base/*"]
    }
  }
}

# Permissions for S3 vectors
data "aws_iam_policy_document" "kb_vector_access" {
  # full access for knowledge base to read, write and manage the vectors bucket.
  statement {
    effect = "Allow"
    actions = [
				"s3vectors:ListIndexes",
				"s3vectors:ListVectors",
                "s3vectors:ListVectorBuckets",
                "s3vectors:ListTagsForResource",

				"s3vectors:GetIndex",
				"s3vectors:GetVectorBucket",
				"s3vectors:GetVectorBucketPolicy",
				"s3vectors:GetVectors",
				
                "s3vectors:QueryVectors",
				"s3vectors:CreateIndex",
				"s3vectors:CreateVectorBucket",
				
                "s3vectors:DeleteIndex",
				"s3vectors:DeleteVectorBucket",
				"s3vectors:DeleteVectors",
				"s3vectors:DeleteVectorBucketPolicy",
				
                "s3vectors:PutVectors",
                "s3vectors:PutVectorBucketPolicy",
				
                "s3vectors:TagResource",
				"s3vectors:UntagResource",
				
				
    ]
    resources = [
      #aws_s3vectors_vector_bucket.s3_vectors_url_embed_vector_store.arn,
      # note currently terraform module has bug and does not output the vector arn as attribute by default
      "arn:aws:s3vectors:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:bucket/${local.name_prefix}-vectors",
      "arn:aws:s3vectors:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:bucket/${local.name_prefix}-vectors/*"
    ]
  }
}

# Permisions for Bedrock model access
data "aws_iam_policy_document" "kb_bedrock_access" {
  # Access to Titan embeddings model
  statement {
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel"
    ]
    resources = [
      "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/${var.embedding_model_id}",
      "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/${var.orchestrator_model_id}",
      "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/${var.ingestion_model_id}"
    ]
  }
}

# Policy for Knowledge Base to read from api-docs bucket
data "aws_iam_policy_document" "kb_s3_source_access" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.api_docs.arn,
      "${aws_s3_bucket.api_docs.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "kb_vector_access" {
  name   = "${local.name_prefix}-kb-vector-access"
  policy = data.aws_iam_policy_document.kb_vector_access.json
}

resource "aws_iam_policy" "kb_bedrock_access" {
  name   = "${local.name_prefix}-kb-bedrock-access"
  policy = data.aws_iam_policy_document.kb_bedrock_access.json
}

resource "aws_iam_policy" "kb_s3_source_access" {
  name        = "${local.name_prefix}-kb-s3-source-access"
  description = "Allow Knowledge Base to read API documentation from S3"
  policy      = data.aws_iam_policy_document.kb_s3_source_access.json
}


# IAM role for Knowledge Base
resource "aws_iam_role" "knowledge_base" {
  name               = "${local.name_prefix}-kb-role"
  assume_role_policy = data.aws_iam_policy_document.kb_trust.json
  
  tags = merge(local.common_tags, {
    Purpose = "Bedrock Knowledge Base execution role"
  })
}

resource "aws_iam_role_policy_attachment" "kb_vector_access" {
  role       = aws_iam_role.knowledge_base.name
  policy_arn = aws_iam_policy.kb_vector_access.arn
}

# Attach Bedrock model access policy
resource "aws_iam_role_policy_attachment" "kb_bedrock_access" {
  role       = aws_iam_role.knowledge_base.name
  policy_arn = aws_iam_policy.kb_bedrock_access.arn
}

resource "aws_iam_role_policy_attachment" "kb_s3_source_access" {
  role       = aws_iam_role.knowledge_base.name
  policy_arn = aws_iam_policy.kb_s3_source_access.arn
}


# Policy for agents to write generated code to S3
data "aws_iam_policy_document" "agents_s3_code_access" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.generated_code.arn,
      "${aws_s3_bucket.generated_code.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "agents_s3_code_access" {
  name        = "${local.name_prefix}-agents-s3-code-access"
  description = "Allow Bedrock agents to write generated code to S3"
  policy      = data.aws_iam_policy_document.agents_s3_code_access.json
}