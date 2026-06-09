# SecurityEngineerRole — security service administration and investigation read access.

data "aws_iam_policy_document" "security_trust" {
  count = var.create_security_role && length(var.allowed_principals) > 0 ? 1 : 0

  source_policy_documents = [data.aws_iam_policy_document.sso_assume_role[0].json]
}

resource "aws_iam_role" "security" {
  count = var.create_security_role && length(var.allowed_principals) > 0 ? 1 : 0

  name                 = "${local.name_prefix}-security-engineer"
  description          = "Security tooling admin and read-only investigation across AWS"
  assume_role_policy   = data.aws_iam_policy_document.security_trust[0].json
  max_session_duration = var.max_session_duration

  tags = merge(local.common_tags, { Role = "SecurityEngineer" })
}

data "aws_iam_policy_document" "security" {
  count = var.create_security_role && length(var.allowed_principals) > 0 ? 1 : 0

  statement {
    sid = "SecurityHubAdmin"
    actions = [
      "securityhub:*",
    ]
    resources = ["*"]
  }

  statement {
    sid = "GuardDutyAdmin"
    actions = [
      "guardduty:*",
    ]
    resources = ["*"]
  }

  statement {
    sid = "InspectorAdmin"
    actions = [
      "inspector2:*",
      "inspector:*",
    ]
    resources = ["*"]
  }

  statement {
    sid = "ConfigAdmin"
    actions = [
      "config:*",
    ]
    resources = ["*"]
  }

  statement {
    sid = "CloudTrailAdmin"
    actions = [
      "cloudtrail:*",
    ]
    resources = ["*"]
  }

  # IAM audit — read and policy simulation only (no CreateUser / AttachUserPolicy on arbitrary principals).
  statement {
    sid = "IAMAuditReadOnly"
    actions = [
      "iam:Get*",
      "iam:List*",
      "iam:GenerateCredentialReport",
      "iam:GenerateServiceLastAccessedDetails",
      "iam:GetServiceLastAccessedDetails",
      "iam:SimulatePrincipalPolicy",
      "iam:SimulateCustomPolicy",
    ]
    resources = ["*"]
  }

  statement {
    sid = "InvestigationReadOnly"
    actions = [
      "ec2:Describe*",
      "s3:Get*",
      "s3:List*",
      "logs:Describe*",
      "logs:Get*",
      "logs:FilterLogEvents",
      "cloudwatch:Describe*",
      "cloudwatch:Get*",
      "kms:Describe*",
      "kms:List*",
      "ssm:Describe*",
      "ssm:Get*",
      "ssm:List*",
      "elasticloadbalancing:Describe*",
      "autoscaling:Describe*",
      "rds:Describe*",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecrets",
      "tag:GetResources",
      "tag:GetTagKeys",
      "tag:GetTagValues",
    ]
    resources = ["*"]
  }

  statement {
    sid = "SecurityReporting"
    actions = [
      "access-analyzer:List*",
      "access-analyzer:Get*",
      "access-analyzer:ValidatePolicy",
      "trustedadvisor:Describe*",
      "health:Describe*",
      "health:DescribeEventDetails",
      "health:DescribeEvents",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "security" {
  count = var.create_security_role && length(var.allowed_principals) > 0 ? 1 : 0

  name        = "${local.name_prefix}-security-engineer-policy"
  description = "Security operations and compliance investigation"
  policy      = data.aws_iam_policy_document.security[0].json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "security" {
  count = var.create_security_role && length(var.allowed_principals) > 0 ? 1 : 0

  role       = aws_iam_role.security[0].name
  policy_arn = aws_iam_policy.security[0].arn
}
