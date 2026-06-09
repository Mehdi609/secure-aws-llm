variable "name_prefix" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "create_hosted_zone" {
  type = bool
}

variable "route53_zone_id" {
  type    = string
  default = null
}

variable "create_dns_record" {
  type = bool
}

variable "alb_arn" {
  type = string
}

variable "alb_dns_name" {
  type = string
}

variable "alb_zone_id" {
  type = string
}

variable "alb_listener_arn" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "api_gateway_security_group_id" {
  type = string
}

variable "static_bucket_id" {
  type = string
}

variable "static_bucket_arn" {
  type = string
}

variable "static_bucket_domain_name" {
  type = string
}

variable "cloudfront_web_acl_arn" {
  type = string
}

variable "api_gateway_web_acl_arn" {
  type = string
}

variable "enable_cloudfront" {
  type = bool
}

variable "cloudfront_certificate_arn" {
  type    = string
  default = null
}

variable "api_stage_name" {
  type = string
}

variable "enable_shield_advanced" {
  type = bool
}
