locals {
  name_prefix        = "${var.project_name}-${var.environment}"
  app_log_group_name = "/aws/ec2/${local.name_prefix}/app"

  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

module "networking" {
  source = "./modules/networking"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  region               = var.region
}

module "storage" {
  source = "./modules/storage"

  name_prefix            = local.name_prefix
  static_bucket_name     = var.static_bucket_name
  dynamodb_table_name    = var.dynamodb_table_name
  dynamodb_hash_key      = var.dynamodb_hash_key
  dynamodb_hash_key_type = var.dynamodb_hash_key_type
  enable_dynamodb_sse    = var.enable_dynamodb_sse
  ssm_parameter_prefix   = var.ssm_parameter_prefix
  ssm_parameters         = var.ssm_parameters
}

module "observability" {
  source = "./modules/observability"

  name_prefix             = local.name_prefix
  app_log_group_name      = local.app_log_group_name
  aws_region              = var.region
  ops_email               = var.ops_email
  app_log_retention_days  = var.app_log_retention_days
  alb_arn_suffix          = module.compute.alb_arn_suffix
  target_group_arn_suffix = module.compute.target_group_arn_suffix
  asg_name                = module.compute.asg_name
  dynamodb_table_name     = module.storage.dynamodb_table_name
  alb_5xx_threshold       = var.alb_5xx_threshold
  cpu_alarm_threshold     = var.cpu_alarm_threshold
}

module "iam" {
  source = "./modules/iam"

  project_name       = var.project_name
  environment        = var.environment
  name_prefix        = local.name_prefix
  aws_region         = var.region
  s3_bucket_arn      = module.storage.static_bucket_arn
  dynamodb_table_arn = module.storage.dynamodb_table_arn
  app_log_group_name = local.app_log_group_name
  ssm_parameter_arns = module.storage.ssm_parameter_arns
  ssm_parameter_prefix = var.ssm_parameter_prefix

  allowed_principals = var.iam_allowed_principals
  tags               = var.tags

  enable_pipeline_role   = var.iam_enable_pipeline_role
  oidc_provider_arn      = var.iam_oidc_provider_arn
  oidc_subject_claims    = var.iam_oidc_subject_claims
  enable_breakglass_role = var.iam_enable_breakglass_role
  breakglass_principals  = var.iam_breakglass_principals
  enable_sagemaker       = var.iam_enable_sagemaker
}

module "security" {
  source = "./modules/security"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name_prefix = local.name_prefix
  vpc_id      = module.networking.vpc_id
}

module "compute" {
  source = "./modules/compute"

  name_prefix           = local.name_prefix
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  private_subnet_ids    = module.networking.private_subnet_ids
  alb_security_group_id = module.security.alb_security_group_id
  ec2_security_group_id = module.security.ec2_security_group_id
  instance_profile_name = module.iam.ec2_instance_profile_name
  ami_id                = var.ami_id
  instance_type         = var.instance_type
  key_name              = var.key_name
  root_volume_size      = var.root_volume_size
  app_log_group_name    = local.app_log_group_name
  app_port              = var.app_port
  user_data_extra       = var.user_data_extra
  asg_min_size          = var.asg_min_size
  asg_max_size          = var.asg_max_size
  asg_desired_capacity  = var.asg_desired_capacity
  cpu_target_value      = var.cpu_target_value
  certificate_arn       = var.alb_certificate_arn
}

module "edge" {
  source = "./modules/edge"

  name_prefix                   = local.name_prefix
  domain_name                   = var.domain_name
  create_hosted_zone            = var.create_hosted_zone
  route53_zone_id               = var.route53_zone_id
  create_dns_record             = var.create_dns_record
  alb_arn                       = module.compute.alb_arn
  alb_dns_name                  = module.compute.alb_dns_name
  alb_zone_id                   = module.compute.alb_zone_id
  alb_listener_arn              = module.compute.http_listener_arn
  private_subnet_ids            = module.networking.private_subnet_ids
  api_gateway_security_group_id = module.security.api_gateway_security_group_id
  static_bucket_id              = module.storage.static_bucket_id
  static_bucket_arn             = module.storage.static_bucket_arn
  static_bucket_domain_name     = module.storage.static_bucket_regional_domain_name
  cloudfront_web_acl_arn        = module.security.cloudfront_web_acl_arn
  api_gateway_web_acl_arn       = module.security.api_gateway_web_acl_arn
  enable_cloudfront             = var.enable_cloudfront
  cloudfront_certificate_arn    = var.cloudfront_certificate_arn
  api_stage_name                = var.api_stage_name
  enable_shield_advanced        = var.enable_shield_advanced
}
