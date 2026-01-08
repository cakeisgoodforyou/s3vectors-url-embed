# Lambda function to fetch API documentation from URLs
# This is called by the Bedrock Ingestion Agent

# IAM role for Lambda
resource "aws_iam_role" "fetch_docs_lambda" {
  name = "${local.name_prefix}-fetch-docs-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = merge(local.common_tags, {
    Purpose = "Fetch API docs from URLs and store in S3"
  })
}

# Policy for Lambda to write to S3 api-docs bucket
data "aws_iam_policy_document" "fetch_docs_lambda_s3" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl"
    ]
    resources = [
      "${aws_s3_bucket.api_docs.arn}/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.api_docs.arn
    ]
  }
}

resource "aws_iam_policy" "fetch_docs_lambda_s3" {
  name        = "${local.name_prefix}-fetch-docs-lambda-s3"
  description = "Allow fetch_docs Lambda to write to S3 api docs bucket"
  policy      = data.aws_iam_policy_document.fetch_docs_lambda_s3.json
}

resource "aws_iam_role_policy_attachment" "fetch_docs_lambda_s3" {
  role       = aws_iam_role.fetch_docs_lambda.name
  policy_arn = aws_iam_policy.fetch_docs_lambda_s3.arn
}

# Attach AWS managed policy for Lambda basic execution
resource "aws_iam_role_policy_attachment" "fetch_docs_lambda_basic" {
  role       = aws_iam_role.fetch_docs_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "fetch_docs_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../src/lambda/fetch_docs"  # Changed from source_file to source_dir
  output_path = "${path.module}/../builds/fetch_docs_lambda.zip"
}


# Lambda function
resource "aws_lambda_function" "fetch_docs" {
  filename         = data.archive_file.fetch_docs_lambda.output_path
  function_name    = "${local.name_prefix}-fetch-docs"
  role             = aws_iam_role.fetch_docs_lambda.arn
  handler          = "handler.lambda_handler"
  source_code_hash = data.archive_file.fetch_docs_lambda.output_base64sha256
  runtime          = var.lambda_runtime
  timeout          = 120
  memory_size      = 512
  architectures    = [var.lambda_architecture]

  environment {
    variables = {
      DOCS_BUCKET = aws_s3_bucket.api_docs.id
      PYTHONPATH      = "/var/task/dependencies"
    }
  }

  tags = merge(local.common_tags, {
    Purpose = "Fetch API documentation from URLs"
  })
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "fetch_docs_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.fetch_docs.function_name}"
  retention_in_days = var.cloudwatch_log_retention_days
  tags              = local.common_tags
}
