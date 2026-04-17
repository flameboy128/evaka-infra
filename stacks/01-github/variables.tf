variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
}

variable "evaka_app_repository_name" {
  description = "eVaka application GitHub repository name for IAM permissions. In format of <your-organization/your-repository-name>"
  type        = string
}

variable "evaka_infra_repository_name" {
  description = "eVaka infrastructure GitHub repository name for IAM permissions. In format of <your-organization/your-repository-name>"
  type        = string
}
variable "env" {
  description = "Name of the environment."
  type        = string
}

variable "name_prefix" {
  description = "Project specific prefix for resources"
  type        = string
}
