output "vpc_id" {
  description = "VPC ID."
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = module.networking.private_subnet_ids
}

output "alb_dns_name" {
  description = "ALB DNS name."
  value       = module.compute.alb_dns_name
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name."
  value       = module.edge.cloudfront_domain_name
}

output "api_endpoint" {
  description = "API Gateway invoke URL."
  value       = module.edge.api_endpoint
}

output "static_bucket_name" {
  description = "S3 bucket for static assets."
  value       = module.storage.static_bucket_id
}

output "dynamodb_table_name" {
  description = "DynamoDB table name."
  value       = module.storage.dynamodb_table_name
}

output "alarm_topic_arn" {
  description = "SNS topic ARN for alarms."
  value       = module.observability.alarm_topic_arn
}
