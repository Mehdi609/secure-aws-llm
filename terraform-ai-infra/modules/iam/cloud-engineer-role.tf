# CloudEngineerRole — infrastructure provisioning (Terraform) with bounded IAM pass-role.

data "aws_iam_policy_document" "cloud_engineer_trust" {
  count = var.create_cloud_engineer_role && length(var.allowed_principals) > 0 ? 1 : 0

  source_policy_documents = [data.aws_iam_policy_document.sso_assume_role[0].json]
}

resource "aws_iam_role" "cloud_engineer" {
  count = var.create_cloud_engineer_role && length(var.allowed_principals) > 0 ? 1 : 0

  name                 = "${local.name_prefix}-cloud-engineer"
  description          = "VPC, compute, data plane, and Terraform deployment (limited IAM)"
  assume_role_policy   = data.aws_iam_policy_document.cloud_engineer_trust[0].json
  max_session_duration = var.max_session_duration

  tags = merge(local.common_tags, { Role = "CloudEngineer" })
}

data "aws_iam_policy_document" "cloud_engineer" {
  count = var.create_cloud_engineer_role && length(var.allowed_principals) > 0 ? 1 : 0

  statement {
    sid = "EC2Infrastructure"
    actions = [
      "ec2:*",
      "autoscaling:Describe*",
      "autoscaling:CreateAutoScalingGroup",
      "autoscaling:UpdateAutoScalingGroup",
      "autoscaling:DeleteAutoScalingGroup",
      "autoscaling:CreateLaunchConfiguration",
      "autoscaling:DeleteLaunchConfiguration",
      "autoscaling:PutScalingPolicy",
      "autoscaling:DeletePolicy",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }

  statement {
    sid = "Networking"
    actions = [
      "ec2:CreateVpc",
      "ec2:DeleteVpc",
      "ec2:ModifyVpcAttribute",
      "ec2:CreateSubnet",
      "ec2:DeleteSubnet",
      "ec2:CreateRouteTable",
      "ec2:DeleteRouteTable",
      "ec2:CreateRoute",
      "ec2:DeleteRoute",
      "ec2:CreateInternetGateway",
      "ec2:DeleteInternetGateway",
      "ec2:AttachInternetGateway",
      "ec2:DetachInternetGateway",
      "ec2:CreateNatGateway",
      "ec2:DeleteNatGateway",
      "ec2:AllocateAddress",
      "ec2:ReleaseAddress",
      "ec2:AssociateRouteTable",
      "ec2:DisassociateRouteTable",
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:CreateTags",
      "ec2:DeleteTags",
    ]
    resources = ["*"]
  }

  statement {
    sid = "LoadBalancers"
    actions = [
      "elasticloadbalancing:*",
    ]
    resources = ["*"]
  }

  statement {
    sid = "RDS"
    actions = [
      "rds:Create*",
      "rds:Delete*",
      "rds:Modify*",
      "rds:Describe*",
      "rds:AddTagsToResource",
      "rds:RemoveTagsFromResource",
      "rds:ListTagsForResource",
    ]
    resources = ["*"]
  }

  statement {
    sid = "KMS"
    actions = [
      "kms:CreateKey",
      "kms:CreateAlias",
      "kms:DeleteAlias",
      "kms:DescribeKey",
      "kms:EnableKeyRotation",
      "kms:GetKeyPolicy",
      "kms:PutKeyPolicy",
      "kms:ScheduleKeyDeletion",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:List*",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]
    resources = ["*"]
  }

  statement {
    sid = "S3Infrastructure"
    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:PutBucketPolicy",
      "s3:DeleteBucketPolicy",
      "s3:PutBucketPublicAccessBlock",
      "s3:PutEncryptionConfiguration",
      "s3:PutLifecycleConfiguration",
      "s3:PutBucketTagging",
      "s3:Get*",
      "s3:List*",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["*"]
  }

  # Limited IAM for Terraform — no user/group admin, no policy version tampering.
  statement {
    sid = "TerraformIAMProvisioning"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:ListPolicyVersions",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:GetInstanceProfile",
      "iam:ListInstanceProfiles",
      "iam:PassRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:TagPolicy",
      "iam:TagInstanceProfile",
    ]
    resources = [
      "arn:aws:iam::${local.account_id}:role/${local.name_prefix}-*",
      "arn:aws:iam::${local.account_id}:policy/${local.name_prefix}-*",
      "arn:aws:iam::${local.account_id}:instance-profile/${local.name_prefix}-*",
      "arn:aws:iam::${local.account_id}:role/aws-service-role/*",
    ]
  }

  statement {
    sid       = "PassRoleToAWSServices"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${local.account_id}:role/${local.name_prefix}-*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values = [
        "ec2.amazonaws.com",
        "elasticloadbalancing.amazonaws.com",
        "autoscaling.amazonaws.com",
        "rds.amazonaws.com",
        "lambda.amazonaws.com",
      ]
    }
  }

  statement {
    sid = "Route53AndACM"
    actions = [
      "route53:*",
      "acm:*",
      "acm-pca:Describe*",
    ]
    resources = ["*"]
  }

  statement {
    sid = "TerraformStateAndLocking"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:DescribeTable",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "cloud_engineer" {
  count = var.create_cloud_engineer_role && length(var.allowed_principals) > 0 ? 1 : 0

  name        = "${local.name_prefix}-cloud-engineer-policy"
  description = "Infrastructure and Terraform execution with scoped IAM"
  policy      = data.aws_iam_policy_document.cloud_engineer[0].json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "cloud_engineer" {
  count = var.create_cloud_engineer_role && length(var.allowed_principals) > 0 ? 1 : 0

  role       = aws_iam_role.cloud_engineer[0].name
  policy_arn = aws_iam_policy.cloud_engineer[0].arn
}
