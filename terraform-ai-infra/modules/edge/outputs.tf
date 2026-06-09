output "route53_zone_id" {
  value = local.hosted_zone_id
}

output "cloudfront_distribution_id" {
  value = var.enable_cloudfront ? aws_cloudfront_distribution.this[0].id : null
}

output "cloudfront_distribution_arn" {
  value = var.enable_cloudfront ? aws_cloudfront_distribution.this[0].arn : null
}

output "cloudfront_domain_name" {
  value = var.enable_cloudfront ? aws_cloudfront_distribution.this[0].domain_name : null
}

output "api_endpoint" {
  value = aws_apigatewayv2_stage.this.invoke_url
}
