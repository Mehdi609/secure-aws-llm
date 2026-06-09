# DevOpsRole — day-2 operations: SSM, scaling, ALB health, backups, CloudWatch admin (no IAM admin).

data "aws_iam_policy_document" "devops_trust" {
  count = var.create_devops_role && length(var.allowed_principals) > 0 ? 1 : 0

  source_policy_documents = [data.aws_iam_policy_document.sso_assume_role[0].json]
}

resource "aws_iam_role" "devops" {
  count = var.create_devops_role && length(var.allowed_principals) > 0 ? 1 : 0

  name                 = "${local.name_prefix}-devops"
  description          = "Operational management for EC2, SSM, ASG, ALB, and observability"
  assume_role_policy   = data.aws_iam_policy_document.devops_trust[0].json
  max_session_duration = var.max_session_duration

  tags = merge(local.common_tags, { Role = "DevOps" })
}

data "aws_iam_policy_document" "devops" {
  count = var.create_devops_role && length(var.allowed_principals) > 0 ? 1 : 0

  statement {
    sid = "EC2Operational"
    actions = [
      "ec2:Describe*",
      "ec2:GetConsoleOutput",
      "ec2:GetConsoleScreenshot",
      "ec2:StartInstances",
      "ec2:StopInstances",
      "ec2:RebootInstances",
      "ec2:ModifyInstanceAttribute",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:ReportInstanceStatus",
    ]
    resources = ["*"]
  }

  statement {
    sid = "SystemsManager"
    actions = [
      "ssm:Describe*",
      "ssm:Get*",
      "ssm:List*",
      "ssm:SendCommand",
      "ssm:CancelCommand",
      "ssm:StartSession",
      "ssm:TerminateSession",
      "ssm:ResumeSession",
      "ssm:PutParameter",
      "ssm:DeleteParameter",
    ]
    resources = ["*"]
  }

  statement {
    sid = "CloudWatchAdministration"
    actions = [
      "cloudwatch:*",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:PutRetentionPolicy",
      "logs:DeleteRetentionPolicy",
      "logs:Describe*",
      "logs:Get*",
      "logs:FilterLogEvents",
      "logs:TagLogGroup",
      "logs:UntagLogGroup",
    ]
    resources = ["*"]
  }

  statement {
    sid = "AutoScalingOperations"
    actions = [
      "autoscaling:Describe*",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "autoscaling:UpdateAutoScalingGroup",
      "autoscaling:SuspendProcesses",
      "autoscaling:ResumeProcesses",
      "autoscaling:PutScalingPolicy",
      "autoscaling:ExecutePolicy",
    ]
    resources = ["*"]
  }

  statement {
    sid = "ApplicationLoadBalancerOps"
    actions = [
      "elasticloadbalancing:Describe*",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:SetRulePriorities",
      "elasticloadbalancing:ModifyListener",
    ]
    resources = ["*"]
  }

  statement {
    sid = "BackupAndRecovery"
    actions = [
      "backup:Describe*",
      "backup:List*",
      "backup:StartBackupJob",
      "backup:StartRestoreJob",
      "backup:StopBackupJob",
      "backup:GetBackupVaultAccessPolicy",
      "ec2:CreateSnapshot",
      "ec2:DeleteSnapshot",
      "ec2:DescribeSnapshots",
      "ec2:CreateTags",
    ]
    resources = ["*"]
  }

  statement {
    sid = "ReadApplicationLogs"
    actions = [
      "logs:GetLogEvents",
      "logs:FilterLogEvents",
      "logs:StartQuery",
      "logs:GetQueryResults",
    ]
    resources = [
      local.app_log_group_arn,
      "${local.app_log_group_arn}:*",
    ]
  }
}

resource "aws_iam_policy" "devops" {
  count = var.create_devops_role && length(var.allowed_principals) > 0 ? 1 : 0

  name        = "${local.name_prefix}-devops-policy"
  description = "DevOps operational access without IAM administration"
  policy      = data.aws_iam_policy_document.devops[0].json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "devops" {
  count = var.create_devops_role && length(var.allowed_principals) > 0 ? 1 : 0

  role       = aws_iam_role.devops[0].name
  policy_arn = aws_iam_policy.devops[0].arn
}
