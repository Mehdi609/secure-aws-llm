# ==============================================================================
# BREAK-GLASS EMERGENCY ROLE — USE ONLY DURING VERIFIED INCIDENTS
# ==============================================================================
# WARNING: This role grants AdministratorAccess equivalent privileges.
# - Requires MFA at assume-role time (aws:MultiFactorAuthPresent).
# - Session limited to one hour (breakglass_max_session_duration).
# - Trust restricted to explicit breakglass_principals (not general SSO users).
# - All usage is logged to CloudTrail — monitor AssumeRole on this ARN.
# - Revoke or disable the role after incident recovery.
# - Prefer SecurityEngineerRole or scoped roles for routine work (Zero Trust).
# ==============================================================================

data "aws_iam_policy_document" "breakglass_trust" {
  count = var.enable_breakglass_role && length(var.breakglass_principals) > 0 ? 1 : 0

  statement {
    sid     = "BreakGlassEmergencyAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = var.breakglass_principals
    }

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }

    # Require recent MFA (within 15 minutes) when supported by identity provider.
    condition {
      test     = "NumericLessThanEquals"
      variable = "aws:MultiFactorAuthAge"
      values   = ["900"]
    }
  }
}

resource "aws_iam_role" "breakglass" {
  count = var.enable_breakglass_role && length(var.breakglass_principals) > 0 ? 1 : 0

  name                 = "${local.name_prefix}-breakglass"
  description          = "EMERGENCY ONLY — full admin with MFA; max 1h session"
  assume_role_policy   = data.aws_iam_policy_document.breakglass_trust[0].json
  max_session_duration = var.breakglass_max_session_duration

  tags = merge(local.common_tags, {
    Role        = "BreakGlass"
    Risk        = "Critical"
    Compliance  = "EmergencyAccess"
    ReviewCycle = "Quarterly"
  })
}

# AWS managed AdministratorAccess — attach as separate policy resource per best practice.
resource "aws_iam_role_policy_attachment" "breakglass_administrator" {
  count = var.enable_breakglass_role && length(var.breakglass_principals) > 0 ? 1 : 0

  role       = aws_iam_role.breakglass[0].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Deny break-glass from disabling CloudTrail (defense in depth during emergency sessions).
data "aws_iam_policy_document" "breakglass_cloudtrail_guard" {
  count = var.enable_breakglass_role && length(var.breakglass_principals) > 0 ? 1 : 0

  statement {
    sid    = "DenyCloudTrailTampering"
    effect = "Deny"
    actions = [
      "cloudtrail:DeleteTrail",
      "cloudtrail:StopLogging",
      "cloudtrail:UpdateTrail",
      "cloudtrail:PutEventSelectors",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "breakglass_cloudtrail_guard" {
  count = var.enable_breakglass_role && length(var.breakglass_principals) > 0 ? 1 : 0

  name        = "${local.name_prefix}-breakglass-cloudtrail-guard"
  description = "Prevent CloudTrail disablement during break-glass sessions"
  policy      = data.aws_iam_policy_document.breakglass_cloudtrail_guard[0].json

  tags = merge(local.common_tags, { Role = "BreakGlassGuard" })
}

resource "aws_iam_role_policy_attachment" "breakglass_cloudtrail_guard" {
  count = var.enable_breakglass_role && length(var.breakglass_principals) > 0 ? 1 : 0

  role       = aws_iam_role.breakglass[0].name
  policy_arn = aws_iam_policy.breakglass_cloudtrail_guard[0].arn
}
