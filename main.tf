# -----------------------------
# Provider Configuration
# -----------------------------
provider "aws" {
  region = "us-east-1"  # Change as needed
}

# -----------------------------
# Random Suffix (for unique names)
# -----------------------------
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# -----------------------------
# S3 Bucket (with unique name)
# -----------------------------
resource "aws_s3_bucket" "trigger_bucket" {
  bucket = "my-s3-lambda-trigger-bucket-${random_string.suffix.result}"
  acl    = "private"

  # Block public access (security best practice)
  force_destroy = true  # Only for dev! Remove in production

  tags = {
    Name = "S3-Lambda-Trigger-Bucket"
  }
}

# -----------------------------
# DynamoDB Table
# -----------------------------
resource "aws_dynamodb_table" "file_metadata" {
  name         = "FileMetadata"
  billing_mode = "PAY_PER_REQUEST"  # No need to manage read/write capacity

  hash_key     = "file_id"  # Primary key (partition key)

  attribute {
    name = "file_id"
    type = "S"  # S = String
  }

  tags = {
    Name = "FileMetadataTable"
  }
}

# -----------------------------
# IAM Role for Lambda
# -----------------------------
resource "aws_iam_role" "lambda_exec_role" {
  name = "s3-lambda-dynamodb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "LambdaExecutionRole"
  }
}

# -----------------------------
# Custom IAM Policy for Lambda (DynamoDB + Logging)
# -----------------------------
resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  name = "lambda-dynamodb-access"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Allow CloudWatch logging
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      },
      # Allow writing to DynamoDB table
      {
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem"
        ],
        Resource = aws_dynamodb_table.file_metadata.arn
      }
    ]
  })
}

# -----------------------------
# Lambda Function
# -----------------------------
resource "aws_lambda_function" "s3_processor" {
  function_name = "s3-file-processor"
  runtime       = "python3.9"
  handler       = "lambda_function.lambda_handler"
  role          = aws_iam_role.lambda_exec_role.arn

  filename         = "lambda_function_payload.zip"
  source_code_hash = filebase64sha256("lambda_function_payload.zip")

  timeout = 60  # seconds

  tags = {
    Environment = "dev"
  }

  depends_on = [aws_iam_role_policy.lambda_dynamodb_policy]
}

# -----------------------------
# Permission: Allow S3 to invoke Lambda
# -----------------------------
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.trigger_bucket.arn
}

# -----------------------------
# S3 Bucket Notification → Lambda
# -----------------------------
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.trigger_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_processor.arn
    events              = ["s3:ObjectCreated:*"]
    # Optional: filter by file type
    # filter_suffix = ".pdf"
  }

  depends_on = [
    aws_lambda_permission.allow_s3_invoke,
    aws_lambda_function.s3_processor
  ]
}
