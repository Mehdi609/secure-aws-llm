# EC2 instance profile — workload identity for Ollama, Open WebUI, agents on Docker hosts.
# Not a human-assumable role; trusts only the EC2 service principal.

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    sid     = "EC2ServiceAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "${local.name_prefix}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = merge(local.common_tags, {
    Role    = "EC2Workload"
    Purpose = "ApplicationRuntime"
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_core" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "ec2_app" {
  statement {
    sid = "ReadStaticAssets"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = flatten([
      for arn in local.application_s3_bucket_arns : [arn, "${arn}/*"]
    ])
  }

  statement {
    sid = "UseApplicationTable"
    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
      "dynamodb:ConditionCheckItem",
      "dynamodb:DeleteItem",
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:UpdateItem",
    ]
    resources = [
      var.dynamodb_table_arn,
      "${var.dynamodb_table_arn}/index/*",
    ]
  }

  statement {
    sid = "WriteApplicationLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = [
      local.app_log_group_arn,
      "${local.app_log_group_arn}:*",
    ]
  }

  statement {
    sid = "ReadApplicationParameters"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]
    resources = local.ssm_parameter_resources
  }
}

resource "aws_iam_policy" "ec2_app" {
  name        = "${local.name_prefix}-ec2-app-policy"
  description = "Least-privilege runtime access for AI platform EC2 instances"
  policy      = data.aws_iam_policy_document.ec2_app.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ec2_app" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.ec2_app.arn
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${local.name_prefix}-ec2-instance-profile"
  role = aws_iam_role.ec2.name

  tags = merge(local.common_tags, {
    Role = "EC2InstanceProfile"
  })
}
