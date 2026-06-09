# DeveloperRole — build/debug access without infrastructure or IAM administration.

data "aws_iam_policy_document" "developer_trust" {
  count = var.create_developer_role && length(var.allowed_principals) > 0 ? 1 : 0

  source_policy_documents = [data.aws_iam_policy_document.sso_assume_role[0].json]
}

resource "aws_iam_role" "developer" {
  count = var.create_developer_role && length(var.allowed_principals) > 0 ? 1 : 0

  name                 = "${local.name_prefix}-developer"
  description          = "Read-only observability and application data access for developers"
  assume_role_policy   = data.aws_iam_policy_document.developer_trust[0].json
  max_session_duration = var.max_session_duration

  tags = merge(local.common_tags, { Role = "Developer" })
}

data "aws_iam_policy_document" "developer" {
  count = var.create_developer_role && length(var.allowed_principals) > 0 ? 1 : 0

  # CloudWatch Logs — read only (no DeleteLogGroup / PutRetentionPolicy).
  statement {
    sid = "ReadApplicationLogs"
    actions = [
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:GetLogEvents",
      "logs:FilterLogEvents",
      "logs:StartQuery",
      "logs:GetQueryResults",
      "logs:StopQuery",
    ]
    resources = [
      local.app_log_group_arn,
      "${local.app_log_group_arn}:*",
    ]
  }

  statement {
    sid = "ReadCloudWatchMetrics"
    actions = [
      "cloudwatch:DescribeAlarms",
      "cloudwatch:DescribeAlarmHistory",
      "cloudwatch:GetMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
    ]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = length(var.cloudwatch_dashboard_arns) > 0 ? [1] : []
    content {
      sid = "ReadMonitoringDashboards"
      actions = [
        "cloudwatch:GetDashboard",
        "cloudwatch:ListDashboards",
      ]
      resources = var.cloudwatch_dashboard_arns
    }
  }

  # Application S3 — read only.
  statement {
    sid = "ReadApplicationBuckets"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = flatten([
      for arn in local.application_s3_bucket_arns : [arn, "${arn}/*"]
    ])
  }

  # ECR — pull metadata and images only.
  statement {
    sid = "ReadContainerImages"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetAuthorizationToken",
      "ecr:GetDownloadUrlForLayer",
      "ecr:ListImages",
    ]
    resources = local.ecr_repository_arns
  }

  statement {
    sid       = "ECRAuthToken"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = length(var.inference_endpoint_arns) > 0 ? [1] : []
    content {
      sid = "InvokeInferenceEndpoints"
      actions = [
        "sagemaker:InvokeEndpoint",
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream",
      ]
      resources = var.inference_endpoint_arns
    }
  }
}

resource "aws_iam_policy" "developer" {
  count = var.create_developer_role && length(var.allowed_principals) > 0 ? 1 : 0

  name        = "${local.name_prefix}-developer-policy"
  description = "Developer read-only access to logs, S3, ECR, and inference"
  policy      = data.aws_iam_policy_document.developer[0].json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "developer" {
  count = var.create_developer_role && length(var.allowed_principals) > 0 ? 1 : 0

  role       = aws_iam_role.developer[0].name
  policy_arn = aws_iam_policy.developer[0].arn
}
