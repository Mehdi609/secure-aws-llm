variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "alb_security_group_id" {
  type = string
}

variable "ec2_security_group_id" {
  type = string
}

variable "instance_profile_name" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "key_name" {
  type    = string
  default = null
}

variable "root_volume_size" {
  type = number
}

variable "app_log_group_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "app_port" {
  type = number
}

variable "backend_image" {
  type = string
}

variable "backend_container_name" {
  type = string
}

variable "ollama_image" {
  type = string
}

variable "ollama_container_name" {
  type = string
}

variable "ollama_model" {
  type = string
}

variable "ollama_num_ctx" {
  type = number
}

variable "ollama_num_predict" {
  type = number
}

variable "ollama_num_thread" {
  type = number
}

variable "ollama_temperature" {
  type = number
}

variable "ollama_keep_alive" {
  type = string
}

variable "google_client_id" {
  type = string
}

variable "user_data_extra" {
  type = string
}

variable "asg_min_size" {
  type = number
}

variable "asg_max_size" {
  type = number
}

variable "asg_desired_capacity" {
  type = number
}

variable "cpu_target_value" {
  type = number
}

variable "certificate_arn" {
  type    = string
  default = null
}
