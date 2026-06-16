region        = "us-west-1"
project_name  = "SecureLLM"
environment   = "prod"
ami_id        = "ami-0729e406b08a646a2"
instance_type = "t3.medium"
domain_name   = "elmehdiboussoufi.me"
# route53_zone_id     = "Z1234567890ABC"
static_bucket_name  = "frontend-files-prod-static"
users_table_name    = "SecureLLM-Users"
chats_table_name    = "SecureLLM-Chats"
messages_table_name = "SecureLLM-Messages"
# dynamodb_table_name = "SecureLLM-table-prod"
# dynamodb_hash_key   = "id"
ops_email         = "contact@elmehdiboussoufi.me"
enable_cloudfront = false



# Optional production values:
# alb_certificate_arn        = "arn:aws:acm:us-west-1:123456789012:certificate/..."
# cloudfront_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/..."
# enable_cloudfront          = true
# create_hosted_zone         = false
# create_dns_record          = true
# enable_shield_advanced     = false
# user_data_extra            = "systemctl start your-app"
