# IAM module — provider requirements (AWS Provider 5.x).
# The root module supplies the configured aws provider; this block declares compatibility only.

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 6.0"
    }
  }
}
