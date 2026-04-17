terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.40.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.2.1"
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
      Service     = "github"
      Stack       = "01-github"
    }
  }
}
