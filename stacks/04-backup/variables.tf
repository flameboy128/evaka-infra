variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
}

variable "env" {
  description = "Name of the environment."
  type        = string
}

variable "evaka_infra_repository_name" {
  description = "eVaka infrastructure GitHub repository name for IAM permissions. In format of <your-organization/your-repository-name>"
  type        = string
}

variable "name_prefix" {
  description = "Project specific prefix for naming resources"
  type        = string
  default     = "evaka"
}

variable "backup_resources" {
  description = "List of ARNs to backup"
  type        = list(string)
  default     = []
}
