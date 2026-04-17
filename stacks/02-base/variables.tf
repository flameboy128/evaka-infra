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

variable "evaka_fqdn" {
  description = "Fully qualified domain name for eVaka. E.g. evaka.example.com"
  type        = string
}

variable "rds_engine_version" {
  description = "Database engine version"
  type        = string
  default     = "17.4"
}

variable "evaka_db_name" {
  description = "Database name for evaka"
  type        = string
  default     = "evaka"
}
