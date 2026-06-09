# ------------------------------------------------------------------------------
# Core project context
# ------------------------------------------------------------------------------

variable "project_name" {
  description = "Project identifier used in IAM resource names and tags."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)."
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID for ARN construction. Defaults to the caller identity account."
  type        = string
  default     = null
}

variable "aws_region" {
  description = "Primary AWS region for regional IAM resource ARNs."
  type        = string
}

variable "name_prefix" {
  description = "Optional override for resource name prefix. Defaults to project_name-environment."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags applied to IAM roles, policies, and instance profiles."
  type        = map(string)
  default     = {}
}

# ------------------------------------------------------------------------------
# IAM Identity Center (AWS SSO) federation
# ------------------------------------------------------------------------------

variable "allowed_principals" {
  description = <<-EOT
    IAM principal ARNs allowed to assume human-operated roles (typically IAM Identity Center
    permission-set roles), e.g. arn:aws:iam::123456789012:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_Developer_abcd1234
  EOT
  type        = list(string)
  default     = []
}

variable "sso_external_id" {
  description = "Optional ExternalId condition for SSO/cross-account assume-role."
  type        = string
  default     = null
}

variable "max_session_duration" {
  description = "Max session duration (seconds) for standard human roles."
  type        = number
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 900 && var.max_session_duration <= 43200
    error_message = "max_session_duration must be between 900 and 43200 seconds."
  }
}

# ------------------------------------------------------------------------------
# Application / workload resource scopes (least privilege)
# ------------------------------------------------------------------------------

variable "s3_bucket_arn" {
  description = "Primary application static/assets S3 bucket ARN."
  type        = string
}

variable "additional_application_s3_bucket_arns" {
  description = "Additional application S3 bucket ARNs (read-only for developers)."
  type        = list(string)
  default     = []
}

variable "ml_s3_bucket_arns" {
  description = "S3 buckets for datasets, model artifacts, and MLflow storage."
  type        = list(string)
  default     = []
}

variable "dynamodb_table_arn" {
  description = "Application DynamoDB table ARN (EC2 workload access)."
  type        = string
}

variable "app_log_group_name" {
  description = "CloudWatch Logs log group for application logs."
  type        = string
}

variable "ssm_parameter_arns" {
  description = "Explicit SSM parameter ARNs for EC2/pipeline access."
  type        = list(string)
  default     = []
}

variable "ssm_parameter_prefix" {
  description = "SSM path prefix when explicit parameter ARNs are not supplied."
  type        = string
  default     = "/ollama"
}

variable "ecr_repository_arns" {
  description = "ECR repository ARNs for image pull/push."
  type        = list(string)
  default     = []
}

variable "deployment_artifact_bucket_arns" {
  description = "S3 buckets holding CI/CD deployment artifacts."
  type        = list(string)
  default     = []
}

variable "deployment_secret_arns" {
  description = "Secrets Manager secret ARNs readable by the pipeline role."
  type        = list(string)
  default     = []
}

variable "inference_endpoint_arns" {
  description = "SageMaker endpoints or other inference ARNs developers may invoke."
  type        = list(string)
  default     = []
}

variable "cloudwatch_dashboard_arns" {
  description = "CloudWatch dashboard ARNs for read-only dashboard access."
  type        = list(string)
  default     = []
}

variable "target_instance_tag_key" {
  description = "EC2 tag key used to scope SSM deploy commands to platform instances."
  type        = string
  default     = "Project"
}

variable "target_instance_tag_value" {
  description = "EC2 tag value used to scope SSM deploy commands."
  type        = string
  default     = null
}

# ------------------------------------------------------------------------------
# Feature flags
# ------------------------------------------------------------------------------

variable "enable_sagemaker" {
  description = "Attach SageMaker permissions to the MLOps role."
  type        = bool
  default     = false
}

variable "enable_mlflow_ssm" {
  description = "Grant MLOps read access to MLflow-related SSM parameters under mlflow prefix."
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# CI/CD OIDC (PipelineDeployRole)
# ------------------------------------------------------------------------------

variable "enable_pipeline_role" {
  description = "Create PipelineDeployRole and OIDC trust (requires oidc_provider_arn)."
  type        = bool
  default     = false
}

variable "oidc_provider_arn" {
  description = "IAM OIDC provider ARN (GitHub Actions, GitLab, etc.)."
  type        = string
  default     = null
}

variable "oidc_audience" {
  description = "Expected aud claim for web identity federation."
  type        = string
  default     = "sts.amazonaws.com"
}

variable "oidc_subject_claims" {
  description = "Allowed sub claim patterns (e.g. repo:org/repo:ref:refs/heads/main)."
  type        = list(string)
  default     = []
}

variable "oidc_audience_claim" {
  description = "JWT aud condition key (e.g. token.actions.githubusercontent.com:aud). Auto-set for GitHub OIDC provider ARNs."
  type        = string
  default     = null
}

variable "oidc_subject_claim" {
  description = "JWT sub condition key (e.g. token.actions.githubusercontent.com:sub). Auto-set for GitHub OIDC provider ARNs."
  type        = string
  default     = null
}

# ------------------------------------------------------------------------------
# Break-glass emergency access
# ------------------------------------------------------------------------------

variable "enable_breakglass_role" {
  description = "Create emergency BreakGlassRole (AdministratorAccess, MFA required)."
  type        = bool
  default     = false
}

variable "breakglass_principals" {
  description = "Explicit principal ARNs allowed to assume BreakGlassRole (subset of trusted admins)."
  type        = list(string)
  default     = []
}

variable "breakglass_max_session_duration" {
  description = "Break-glass session cap in seconds (max 3600 recommended)."
  type        = number
  default     = 3600

  validation {
    condition     = var.breakglass_max_session_duration >= 900 && var.breakglass_max_session_duration <= 3600
    error_message = "breakglass_max_session_duration must be between 900 and 3600 seconds."
  }
}

# ------------------------------------------------------------------------------
# Role creation toggles (deploy incrementally in new accounts)
# ------------------------------------------------------------------------------

variable "create_developer_role" {
  type    = bool
  default = true
}

variable "create_mlops_role" {
  type    = bool
  default = true
}

variable "create_cloud_engineer_role" {
  type    = bool
  default = true
}

variable "create_devops_role" {
  type    = bool
  default = true
}

variable "create_security_role" {
  type    = bool
  default = true
}
