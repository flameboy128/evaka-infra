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

variable "log_retention_in_days" {
  description = "CloudWatch Log retention in days"
  type        = number
  default     = 30
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs"
  type        = list(string)
}

variable "evaka_fqdn" {
  description = "Fully qualified domain name for evaka"
  type        = string
}

variable "waf_enabled" {
  description = "Enable AWS WAF for the Application Load Balancer"
  type        = bool
  default     = true
}

variable "allow_access_from" {
  description = "CIDR/description pairs to allow access from"
  type        = map(string)
  default     = {}
}

variable "rds_database_endpoint_address" {
  description = "Database endpoint address for RDS"
  type        = string
}

variable "rds_database_endpoint_port" {
  description = "Database endpoint port for RDS"
  type        = string
}

variable "rds_security_group_id" {
  description = "Security group ID for RDS"
  type        = string
}

variable "evaka_db_name" {
  description = "Database name for evaka"
  type        = string
  default     = "evaka"
}

variable "evaka_db_migration_user_password_arn" {
  description = "Secrets Manager ARN for eVaka migration (flyway) database user"
  type        = string
}

variable "evaka_db_application_user_password_arn" {
  description = "Secrets Manager ARN for eVaka application database user"
  type        = string
}

variable "evaka_dummy_idp_image" {
  description = "Container image for eVaka Dummy IDP"
  type        = string
  default     = ""
}

variable "evaka_frontend_image" {
  description = "Container image for eVaka Frontend"
  type        = string
}

variable "evaka_apigw_image" {
  description = "Container image for eVaka API Gateway"
  type        = string
}

variable "evaka_service_image" {
  description = "Container image for eVaka Service"
  type        = string
}

variable "evaka_frontend_envvars" {
  description = "Environment variables for eVaka Frontend"
  type        = map(string)
  default     = {}
}

variable "evaka_apigw_envvars" {
  description = "Environment variables for eVaka API Gateway"
  type        = map(string)
  default     = {}
}

variable "evaka_apigw_secrets" {
  description = "Secret arns for eVaka API Gateway"
  type        = map(string)
  default     = {}
}

variable "evaka_service_envvars" {
  description = "Environment variables for eVaka Service"
  type        = map(string)
  default     = {}
}

variable "evaka_service_secrets" {
  description = "Secret arns for eVaka Service"
  type        = map(string)
  default     = {}
}
