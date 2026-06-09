# MLOpsRole — model lifecycle, datasets, artifacts, and observability for ML engineers.

data "aws_iam_policy_document" "mlops_trust" {
  count = var.create_mlops_role && length(var.allowed_principals) > 0 ? 1 : 0

  source_policy_documents = [data.aws_iam_policy_document.sso_assume_role[0].json]
}

resource "aws_iam_role" "mlops" {
  count = var.create_mlops_role && length(var.allowed_principals) > 0 ? 1 : 0

  name                 = "${local.name_prefix}-mlops"
  description          = "Model registry, dataset, and ML platform operations (no IAM admin)"
  assume_role_policy   = data.aws_iam_policy_document.mlops_trust[0].json
  max_session_duration = var.max_session_duration

  tags = merge(local.common_tags, { Role = "MLOps" })
}

data "aws_iam_policy_document" "mlops" {
  count = var.create_mlops_role && length(var.allowed_principals) > 0 ? 1 : 0

  statement {
    sid = "MLDataAndArtifactsS3"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
    ]
    resources = flatten([
      for arn in local.ml_s3_bucket_arns : [arn, "${arn}/*"]
    ])
  }

  statement {
    sid = "CloudWatchMetricsAndLogs"
    actions = [
      "cloudwatch:DescribeAlarms",
      "cloudwatch:GetMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:GetLogEvents",
      "logs:FilterLogEvents",
      "logs:StartQuery",
      "logs:GetQueryResults",
    ]
    resources = ["*"]
  }

  statement {
    sid = "ApplicationLogGroupRead"
    actions = [
      "logs:GetLogEvents",
      "logs:FilterLogEvents",
    ]
    resources = [
      local.app_log_group_arn,
      "${local.app_log_group_arn}:*",
    ]
  }

  dynamic "statement" {
    for_each = var.enable_mlflow_ssm ? [1] : []
    content {
      sid = "MLflowConfigurationSSM"
      actions = [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath",
        "ssm:DescribeParameters",
      ]
      resources = [
        "arn:aws:ssm:${var.aws_region}:${local.account_id}:parameter/${local.name_prefix}/mlflow/*",
        "arn:aws:ssm:${var.aws_region}:${local.account_id}:parameter/mlflow/*",
      ]
    }
  }

  dynamic "statement" {
    for_each = var.enable_sagemaker ? [1] : []
    content {
      sid = "SageMakerModelLifecycle"
      actions = [
        "sagemaker:Describe*",
        "sagemaker:List*",
        "sagemaker:CreateModel",
        "sagemaker:CreateEndpointConfig",
        "sagemaker:CreateEndpoint",
        "sagemaker:UpdateEndpoint",
        "sagemaker:CreateTrainingJob",
        "sagemaker:CreateProcessingJob",
        "sagemaker:StopTrainingJob",
        "sagemaker:StopProcessingJob",
        "sagemaker:AddTags",
        "sagemaker:DeleteTags",
      ]
      resources = [
        "arn:aws:sagemaker:${var.aws_region}:${local.account_id}:*",
      ]
    }
  }

  dynamic "statement" {
    for_each = var.enable_sagemaker ? [1] : []
    content {
      sid       = "SageMakerPassRoleForJobs"
      actions   = ["iam:PassRole"]
      resources = ["arn:aws:iam::${local.account_id}:role/${local.name_prefix}-sagemaker-*"]
      condition {
        test     = "StringEquals"
        variable = "iam:PassedToService"
        values   = ["sagemaker.amazonaws.com"]
      }
    }
  }

  statement {
    sid = "ECRPullForModelImages"
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
    ]
    resources = local.ecr_repository_arns
  }

  statement {
    sid       = "ECRAuthToken"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "mlops" {
  count = var.create_mlops_role && length(var.allowed_principals) > 0 ? 1 : 0

  name        = "${local.name_prefix}-mlops-policy"
  description = "MLOps access to ML data, observability, and optional SageMaker"
  policy      = data.aws_iam_policy_document.mlops[0].json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "mlops" {
  count = var.create_mlops_role && length(var.allowed_principals) > 0 ? 1 : 0

  role       = aws_iam_role.mlops[0].name
  policy_arn = aws_iam_policy.mlops[0].arn
}
