# PipelineDeployRole — CI/CD via OIDC (GitHub Actions / GitLab / Jenkins).
# Deploy-only: ECR, SSM Run Command, artifacts S3, Secrets Manager read. No infra create / IAM admin.

# locals {
#   pipeline_oidc_audience_claim = coalesce(
#     var.oidc_audience_claim,
#     can(regex("token\\.actions\\.githubusercontent\\.com", coalesce(var.oidc_provider_arn, "")))
#     ? "token.actions.githubusercontent.com:aud"
#     : null
#   )
#   pipeline_oidc_subject_claim = coalesce(
#     var.oidc_subject_claim,
#     can(regex("token\\.actions\\.githubusercontent\\.com", coalesce(var.oidc_provider_arn, "")))
#     ? "token.actions.githubusercontent.com:sub"
#     : null
#   )



#   pipeline_create_enabled = (
#     var.enable_pipeline_role
#     && var.oidc_provider_arn != null
#     && length(var.oidc_subject_claims) > 0
#     && local.pipeline_oidc_audience_claim != null
#     && local.pipeline_oidc_subject_claim != null
#   )

#   pipeline_target_tag_value = coalesce(var.target_instance_tag_value, var.project_name)
# }

locals {
  pipeline_oidc_audience_claim = var.oidc_audience_claim != null ? var.oidc_audience_claim : (
    var.oidc_provider_arn != null &&
    can(regex("token\\.actions\\.githubusercontent\\.com", var.oidc_provider_arn))
    ? "token.actions.githubusercontent.com:aud"
    : null
  )

  pipeline_oidc_subject_claim = var.oidc_subject_claim != null ? var.oidc_subject_claim : (
    var.oidc_provider_arn != null &&
    can(regex("token\\.actions\\.githubusercontent\\.com", var.oidc_provider_arn))
    ? "token.actions.githubusercontent.com:sub"
    : null
  )

  pipeline_create_enabled = (
    var.enable_pipeline_role
    && var.oidc_provider_arn != null
    && length(var.oidc_subject_claims) > 0
    && local.pipeline_oidc_audience_claim != null
    && local.pipeline_oidc_subject_claim != null
  )

  pipeline_target_tag_value = coalesce(var.target_instance_tag_value, var.project_name)
}

data "aws_iam_policy_document" "pipeline_oidc_trust" {
  count = local.pipeline_create_enabled ? 1 : 0

  statement {
    sid     = "OIDCWebIdentityAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = local.pipeline_oidc_audience_claim
      values   = [var.oidc_audience]
    }

    condition {
      test     = "StringLike"
      variable = local.pipeline_oidc_subject_claim
      values   = var.oidc_subject_claims
    }
  }
}

locals {
  pipeline_trust_policy = local.pipeline_create_enabled ? data.aws_iam_policy_document.pipeline_oidc_trust[0].json : null
}

resource "aws_iam_role" "pipeline" {
  count = local.pipeline_trust_policy != null ? 1 : 0

  name                 = "${local.name_prefix}-pipeline-deploy"
  description          = "CI/CD deployment to EC2 via SSM — no infrastructure or IAM administration"
  assume_role_policy   = local.pipeline_trust_policy
  max_session_duration = 3600

  tags = merge(local.common_tags, { Role = "PipelineDeploy" })
}

data "aws_iam_policy_document" "pipeline" {
  count = local.pipeline_trust_policy != null ? 1 : 0

  statement {
    sid = "ECRPushAndPull"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetAuthorizationToken",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:ListImages",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = local.ecr_repository_arns
  }

  statement {
    sid       = "ECRAuthToken"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "ReadDeploymentArtifacts"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = flatten([
      for arn in local.deployment_artifact_bucket_arns : [arn, "${arn}/*"]
    ])
  }

  statement {
    sid = "ReadDeploymentSecrets"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = local.deployment_secret_arns
  }

  # Deploy and restart services on tagged EC2 instances via SSM — no RunInstances/Create*.
  statement {
    sid = "SSMDeployToTargetInstances"
    actions = [
      "ssm:SendCommand",
      "ssm:GetCommandInvocation",
      "ssm:ListCommandInvocations",
      "ssm:ListCommands",
      "ssm:CancelCommand",
      "ssm:DescribeInstanceInformation",
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${local.account_id}:document/AWS-RunShellScript",
      "arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript",
      "arn:aws:ec2:${var.aws_region}:${local.account_id}:instance/*",
    ]
  }

  statement {
    sid = "SSMCommandResultBuckets"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = [
      "arn:aws:s3:::aws-ssm-${var.aws_region}/*",
      "arn:aws:s3:::aws-ssm-*/*",
    ]
  }

  statement {
    sid       = "DiscoverTargetInstances"
    actions   = ["ec2:DescribeInstances", "ec2:DescribeTags"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/${var.target_instance_tag_key}"
      values   = [local.pipeline_target_tag_value]
    }
  }
}

resource "aws_iam_policy" "pipeline" {
  count = local.pipeline_trust_policy != null ? 1 : 0

  name        = "${local.name_prefix}-pipeline-deploy-policy"
  description = "CI/CD ECR, S3 artifacts, Secrets Manager, and SSM deployment"
  policy      = data.aws_iam_policy_document.pipeline[0].json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "pipeline" {
  count = local.pipeline_trust_policy != null ? 1 : 0

  role       = aws_iam_role.pipeline[0].name
  policy_arn = aws_iam_policy.pipeline[0].arn
}
