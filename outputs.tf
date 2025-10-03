# outputs.tf

output "s3_bucket_name" {
  value = aws_s3_bucket.trigger_bucket.bucket
}

output "lambda_function_name" {
  value = aws_lambda_function.s3_processor.function_name
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.file_metadata.name
}
