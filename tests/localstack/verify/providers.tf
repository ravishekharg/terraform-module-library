# LocalStack on localhost:4566 (community edition): fake credentials, no account lookups.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.70, < 7.0"
    }
  }
}

provider "aws" {
  region                      = "eu-west-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    ec2  = "http://localhost:4566"
    iam  = "http://localhost:4566"
    logs = "http://localhost:4566"
    s3   = "http://localhost:4566"
    sts  = "http://localhost:4566"
  }
}
