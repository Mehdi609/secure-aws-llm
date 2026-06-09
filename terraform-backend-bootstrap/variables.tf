variable "region" {
  description = "AWS region where Terraform backend resources are created."
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform remote state."
  type        = string
  default     = "securellm-tfstate-elmehdi-2026"
}

variable "lock_table_name" {
  description = "DynamoDB table name for Terraform state locking."
  type        = string
  default     = "tf-state-lock"
}

variable "project_name" {
  description = "Project name used in tags."
  type        = string
  default     = "SecureLLM"
}

variable "environment" {
  description = "Environment name used in tags."
  type        = string
  default     = "bootstrap"
}

variable "tags" {
  description = "Additional tags to apply to backend resources."
  type        = map(string)
  default     = {}
}
