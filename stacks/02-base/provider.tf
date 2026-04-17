terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.40.0"
    }
  }
}

provider "aws" {
  allowed_account_ids = [var.aws_account_id]
  region              = var.aws_region

  default_tags {
    tags = {
      Environment = var.env
      Repository  = var.evaka_infra_repository_name
      Service     = "evaka-base-infra"
      Stack       = "02-base"
    }
  }
}
