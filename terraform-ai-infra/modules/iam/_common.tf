# Shared identity, naming, tagging, and IAM Identity Center (SSO) assume-role trust.

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  account_id  = coalesce(var.aws_account_id, data.aws_caller_identity.current.account_id)
  partition   = data.aws_partition.current.partition
  name_prefix = coalesce(var.name_prefix, "${var.project_name}-${var.environment}")

  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      Module      = "iam"
      ManagedBy   = "Terraform"
    },
    var.tags
  )

  app_log_group_arn = "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:${var.app_log_group_name}"

  application_s3_bucket_arns = distinct(concat(
    [var.s3_bucket_arn],
    var.additional_application_s3_bucket_arns,
  ))

  ml_s3_bucket_arns = length(var.ml_s3_bucket_arns) > 0 ? var.ml_s3_bucket_arns : local.application_s3_bucket_arns

  ecr_repository_arns = length(var.ecr_repository_arns) > 0 ? var.ecr_repository_arns : [
    "arn:aws:ecr:${var.aws_region}:${local.account_id}:repository/${local.name_prefix}/*"
  ]

  ssm_parameter_resources = length(var.ssm_parameter_arns) > 0 ? var.ssm_parameter_arns : [
    "arn:aws:ssm:${var.aws_region}:${local.account_id}:parameter/${var.ssm_parameter_prefix}/*"
  ]

  deployment_secret_arns = length(var.deployment_secret_arns) > 0 ? var.deployment_secret_arns : [
    "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:${local.name_prefix}/*"
  ]

  deployment_artifact_bucket_arns = length(var.deployment_artifact_bucket_arns) > 0 ? var.deployment_artifact_bucket_arns : local.application_s3_bucket_arns
}

# Trust policy fragment for roles assumed via IAM Identity Center permission sets.
data "aws_iam_policy_document" "sso_assume_role" {
  count = length(var.allowed_principals) > 0 ? 1 : 0

  statement {
    sid     = "AllowIdentityCenterAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = var.allowed_principals
    }

    # Optional external ID for cross-account SSO or delegated administration.
    dynamic "condition" {
      for_each = var.sso_external_id != null ? [1] : []
      content {
        test     = "StringEquals"
        variable = "sts:ExternalId"
        values   = [var.sso_external_id]
      }
    }
  }
}
