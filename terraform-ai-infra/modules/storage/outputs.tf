output "static_bucket_id" {
  value = aws_s3_bucket.static.id
}

output "static_bucket_arn" {
  value = aws_s3_bucket.static.arn
}

output "static_bucket_regional_domain_name" {
  value = aws_s3_bucket.static.bucket_regional_domain_name
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.this.name
}

output "dynamodb_table_arn" {
  value = aws_dynamodb_table.this.arn
}

output "ssm_parameter_arns" {
  value = [for parameter in aws_ssm_parameter.this : parameter.arn]
}
