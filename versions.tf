terraform {
  required_version = ">= 1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.58"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# Add the S3 backend before production use.
# The bucket and lock table must be created first.

# backend "s3" {
#   bucket         = "REPLACE-ME-tfstate-bucket"
#   key            = "wazuh/terraform.tfstate"
#   region         = "eu-west-2"
#   dynamodb_table = "REPLACE-ME-tfstate-lock"
#   encrypt        = true
# }
