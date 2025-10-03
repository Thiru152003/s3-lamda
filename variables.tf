# variables.tf

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name_prefix" {
  description = "Prefix for S3 bucket name (must be globally unique)"
  type        = string
  validation {
    condition     = length(var.bucket_name_prefix) >= 3 && length(var.bucket_name_prefix) <= 20
    error_message = "Bucket prefix must be 3–20 characters long."
  }
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "s3-file-processor"
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  type        = string
  default     = "FileMetadata"
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"
}
