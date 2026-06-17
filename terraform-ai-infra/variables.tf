

variable "region" {
  description = "AWS region for regional resources."
  type        = string
  default     = "us-west-1"
}

variable "project_name" {
  description = "Project name used in resource names."
  type        = string
  default     = "ollama"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "prod"
}

variable "tags" {
  description = "Additional tags applied to all supported resources."
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Two Availability Zones for the workload."
  type        = list(string)
  default     = ["us-west-1a", "us-west-1c"]

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Exactly two Availability Zones are required."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets."
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Exactly two public subnet CIDRs are required."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) == 2
    error_message = "Exactly two private subnet CIDRs are required."
  }
}

variable "ami_id" {
  description = "AMI ID for EC2 instances, such as a current Amazon Linux 2 AMI."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the launch template."
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "Optional EC2 key pair name. SSM is preferred for access."
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 30
}

variable "app_port" {
  description = "Local backend application port proxied by nginx on port 80."
  type        = number
  default     = 8000
}

variable "backend_image" {
  description = "Backend Docker image used by EC2 user data for first boot self-configuration."
  type        = string
  default     = "mehdi609/ai-backend:latest"
}

variable "backend_container_name" {
  description = "Backend Docker container name."
  type        = string
  default     = "ai-backend"
}

variable "ollama_image" {
  description = "Ollama Docker image used by EC2 user data."
  type        = string
  default     = "ollama/ollama"
}

variable "ollama_container_name" {
  description = "Ollama Docker container name."
  type        = string
  default     = "ollama"
}

variable "ollama_model" {
  description = "Ollama model pulled on EC2 first boot."
  type        = string
  default     = "qwen2.5:1.5b"
}

variable "ollama_num_ctx" {
  description = "Ollama context window for backend generation."
  type        = number
  default     = 2048
}

variable "ollama_num_predict" {
  description = "Ollama max generated tokens for backend generation."
  type        = number
  default     = 128
}

variable "ollama_num_thread" {
  description = "Ollama CPU threads for backend generation."
  type        = number
  default     = 2
}

variable "ollama_temperature" {
  description = "Ollama generation temperature."
  type        = number
  default     = 0.3
}

variable "ollama_keep_alive" {
  description = "How long Ollama keeps the model loaded."
  type        = string
  default     = "30m"
}

variable "google_client_id" {
  description = "Google OAuth client ID passed to the backend container."
  type        = string
  default     = "774483348931-p8ji6js5ihhgndg06ikk80r0iuoapbsa.apps.googleusercontent.com"
}

variable "user_data_extra" {
  description = "Additional shell commands appended to EC2 user data."
  type        = string
  default     = ""
}

variable "asg_min_size" {
  description = "Minimum ASG size."
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximum ASG size."
  type        = number
  default     = 6
}

variable "asg_desired_capacity" {
  description = "Desired ASG capacity."
  type        = number
  default     = 2
}

variable "cpu_target_value" {
  description = "Target tracking CPU utilization percentage."
  type        = number
  default     = 60
}

variable "alb_certificate_arn" {
  description = "Optional ACM certificate ARN in us-west-1 for ALB HTTPS."
  type        = string
  default     = null
}

variable "cloudfront_certificate_arn" {
  description = "Optional ACM certificate ARN in us-east-1 for CloudFront aliases."
  type        = string
  default     = null
}

variable "enable_cloudfront" {
  description = "Whether to create the CloudFront distribution. Disable if the AWS account is not yet verified for CloudFront."
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "Domain name for Route 53 and optional CloudFront alias."
  type        = string
}

variable "create_hosted_zone" {
  description = "Whether to create a Route 53 hosted zone for domain_name."
  type        = bool
  default     = false
}

variable "route53_zone_id" {
  description = "Existing Route 53 hosted zone ID. Required when create_hosted_zone is false and DNS records are enabled."
  type        = string
  default     = null
}

variable "create_dns_record" {
  description = "Whether to create an Alias A record for domain_name."
  type        = bool
  default     = true
}

variable "api_stage_name" {
  description = "API Gateway stage name."
  type        = string
  default     = "prod"
}

variable "static_bucket_name" {
  description = "Globally unique S3 bucket name for React static files."
  type        = string
}

variable "users_table_name" {
  description = "Users DynamoDB table name."
  type        = string
  default     = "SecureLLM-Users"
}

variable "chats_table_name" {
  description = "Chats DynamoDB table name."
  type        = string
  default     = "SecureLLM-Chats"
}

variable "messages_table_name" {
  description = "Messages DynamoDB table name."
  type        = string
  default     = "SecureLLM-Messages"
}

variable "enable_dynamodb_sse" {
  description = "Enable DynamoDB server-side encryption."
  type        = bool
  default     = true
}

variable "ssm_parameter_prefix" {
  description = "Prefix for SSM Parameter Store entries."
  type        = string
  default     = "/ollama/prod"
}

variable "ssm_parameters" {
  description = "SecureString SSM parameters to create under ssm_parameter_prefix."
  type        = map(string)
  default     = {}
}

variable "ops_email" {
  description = "Email address subscribed to SNS alarm notifications."
  type        = string
}

variable "app_log_retention_days" {
  description = "Application log group retention in days."
  type        = number
  default     = 30
}

variable "alb_5xx_threshold" {
  description = "ALB 5xx count alarm threshold over the evaluation window."
  type        = number
  default     = 10
}

variable "cpu_alarm_threshold" {
  description = "ASG CPU alarm threshold."
  type        = number
  default     = 80
}

variable "enable_shield_advanced" {
  description = "Create Shield Advanced protection for CloudFront. Requires an active Shield Advanced subscription."
  type        = bool
  default     = false
}

# ------------------------------------------------------------------------------
# IAM module — human roles, CI/CD OIDC, break-glass
# ------------------------------------------------------------------------------

variable "iam_allowed_principals" {
  description = <<-EOT
    IAM Identity Center permission-set role ARNs allowed to assume developer/mlops/cloud-engineer/devops/security roles.
    Example: arn:aws:iam::123456789012:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_Developer_*
  EOT
  type        = list(string)
  default     = []
}

variable "iam_enable_pipeline_role" {
  description = "Create PipelineDeployRole with OIDC federation (requires iam_oidc_provider_arn and subject claims)."
  type        = bool
  default     = false
}

variable "iam_oidc_provider_arn" {
  description = "IAM OIDC provider ARN for GitHub Actions, GitLab CI, etc."
  type        = string
  default     = null
}

variable "iam_oidc_subject_claims" {
  description = "Allowed OIDC sub claim patterns for the pipeline role."
  type        = list(string)
  default     = []
}

variable "iam_enable_breakglass_role" {
  description = "Create emergency BreakGlassRole (AdministratorAccess + MFA)."
  type        = bool
  default     = false
}

variable "iam_breakglass_principals" {
  description = "Principal ARNs allowed to assume BreakGlassRole (separate from general SSO users)."
  type        = list(string)
  default     = []
}

variable "iam_enable_sagemaker" {
  description = "Grant SageMaker permissions to the MLOps role."
  type        = bool
  default     = false
}
