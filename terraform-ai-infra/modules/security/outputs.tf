output "alb_security_group_id" {
  value = aws_security_group.alb.id
}

output "ec2_security_group_id" {
  value = aws_security_group.ec2.id
}

output "api_gateway_security_group_id" {
  value = aws_security_group.api_gateway_vpc_link.id
}

output "cloudfront_web_acl_arn" {
  value = aws_wafv2_web_acl.cloudfront.arn
}

output "api_gateway_web_acl_arn" {
  value = aws_wafv2_web_acl.api_gateway.arn
}
