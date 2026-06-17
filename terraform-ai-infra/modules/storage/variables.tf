variable "name_prefix" {
  type = string
}

variable "static_bucket_name" {
  type = string
}

variable "block_public_access" {
  description = "Block public access to the static bucket. Keep true when CloudFront OAC is enabled; false only for S3 website fallback."
  type        = bool
  default     = true
}

# variable "dynamodb_table_name" {
#   type = string
# }

# variable "dynamodb_hash_key" {
#   type = string
# }

# variable "dynamodb_hash_key_type" {
#   type = string
# }

variable "users_table_name" {
  type = string
}

variable "chats_table_name" {
  type = string
}

variable "messages_table_name" {
  type = string
}

variable "enable_dynamodb_sse" {
  type = bool
}

variable "ssm_parameter_prefix" {
  type = string
}

variable "ssm_parameters" {
  type = map(string)
}
