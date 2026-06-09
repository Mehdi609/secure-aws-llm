# EC2 workload identity (required by compute module)
output "ec2_role_name" {
  description = "IAM role name attached to EC2 instances."
  value       = aws_iam_role.ec2.name
}

output "ec2_role_arn" {
  description = "IAM role ARN for EC2 workload."
  value       = aws_iam_role.ec2.arn
}

output "ec2_instance_profile_name" {
  description = "Instance profile name for the launch template / ASG."
  value       = aws_iam_instance_profile.ec2.name
}

output "ec2_instance_profile_arn" {
  description = "Instance profile ARN."
  value       = aws_iam_instance_profile.ec2.arn
}

# Human and automation roles
output "developer_role_arn" {
  description = "DeveloperRole ARN (null if not created)."
  value       = try(aws_iam_role.developer[0].arn, null)
}

output "mlops_role_arn" {
  description = "MLOpsRole ARN (null if not created)."
  value       = try(aws_iam_role.mlops[0].arn, null)
}

output "cloud_engineer_role_arn" {
  description = "CloudEngineerRole ARN (null if not created)."
  value       = try(aws_iam_role.cloud_engineer[0].arn, null)
}

output "devops_role_arn" {
  description = "DevOpsRole ARN (null if not created)."
  value       = try(aws_iam_role.devops[0].arn, null)
}

output "pipeline_deploy_role_arn" {
  description = "PipelineDeployRole ARN (null if OIDC pipeline role not enabled)."
  value       = try(aws_iam_role.pipeline[0].arn, null)
}

output "security_engineer_role_arn" {
  description = "SecurityEngineerRole ARN (null if not created)."
  value       = try(aws_iam_role.security[0].arn, null)
}

output "breakglass_role_arn" {
  description = "BreakGlassRole ARN (null if emergency role not enabled)."
  value       = try(aws_iam_role.breakglass[0].arn, null)
}

output "role_arns" {
  description = "Map of logical role names to ARNs for Identity Center assignment."
  value = {
    ec2_workload      = aws_iam_role.ec2.arn
    developer         = try(aws_iam_role.developer[0].arn, null)
    mlops             = try(aws_iam_role.mlops[0].arn, null)
    cloud_engineer    = try(aws_iam_role.cloud_engineer[0].arn, null)
    devops            = try(aws_iam_role.devops[0].arn, null)
    pipeline_deploy   = try(aws_iam_role.pipeline[0].arn, null)
    security_engineer = try(aws_iam_role.security[0].arn, null)
    breakglass        = try(aws_iam_role.breakglass[0].arn, null)
  }
}
