variable "name_prefix" {
  type = string
}

variable "app_log_group_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "ops_email" {
  type = string
}

variable "app_log_retention_days" {
  type = number
}

variable "alb_arn_suffix" {
  type = string
}

variable "target_group_arn_suffix" {
  type = string
}

variable "asg_name" {
  type = string
}

variable "dynamodb_table_name" {
  type = string
}

variable "alb_5xx_threshold" {
  type = number
}

variable "cpu_alarm_threshold" {
  type = number
}
