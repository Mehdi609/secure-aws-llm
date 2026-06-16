resource "aws_s3_bucket" "static" {
  bucket = var.static_bucket_name

  tags = {
    Name = var.static_bucket_name
  }
}

resource "aws_s3_bucket_versioning" "static" {
  bucket = aws_s3_bucket.static.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "static" {
  bucket = aws_s3_bucket.static.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "static" {
  bucket = aws_s3_bucket.static.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "static" {
  bucket = aws_s3_bucket.static.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_dynamodb_table" "users" {
  name         = var.users_table_name
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "user_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  server_side_encryption {
    enabled = var.enable_dynamodb_sse
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = var.users_table_name
  }
}

resource "aws_dynamodb_table" "chats" {
  name         = var.chats_table_name
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "chat_id"

  attribute {
    name = "chat_id"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  global_secondary_index {
    name            = "UserChatsIndex"
    hash_key        = "user_id"
    projection_type = "ALL"
  }

  server_side_encryption {
    enabled = var.enable_dynamodb_sse
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = var.chats_table_name
  }
}

resource "aws_dynamodb_table" "messages" {
  name         = var.messages_table_name
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "chat_id"
  range_key = "seq"

  attribute {
    name = "chat_id"
    type = "S"
  }

  attribute {
    name = "seq"
    type = "N"
  }

  server_side_encryption {
    enabled = var.enable_dynamodb_sse
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = var.messages_table_name
  }
}

resource "aws_ssm_parameter" "this" {
  for_each = var.ssm_parameters

  name  = "${trimsuffix(var.ssm_parameter_prefix, "/")}/${each.key}"
  type  = "SecureString"
  value = each.value
}
