variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "bucket_name_prefix" {
  description = "Prefix for S3 bucket name"
  default     = "s3-lambda-app"
}
