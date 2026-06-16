output "static_bucket_id" {
  value = aws_s3_bucket.static.id
}

output "static_bucket_arn" {
  value = aws_s3_bucket.static.arn
}

output "static_bucket_regional_domain_name" {
  value = aws_s3_bucket.static.bucket_regional_domain_name
}

output "users_table_name" {
  value = aws_dynamodb_table.users.name
}

output "users_table_arn" {
  value = aws_dynamodb_table.users.arn
}

output "chats_table_name" {
  value = aws_dynamodb_table.chats.name
}

output "chats_table_arn" {
  value = aws_dynamodb_table.chats.arn
}

output "messages_table_name" {
  value = aws_dynamodb_table.messages.name
}

output "messages_table_arn" {
  value = aws_dynamodb_table.messages.arn
}

output "ssm_parameter_arns" {
  value = [for parameter in aws_ssm_parameter.this : parameter.arn]
}
