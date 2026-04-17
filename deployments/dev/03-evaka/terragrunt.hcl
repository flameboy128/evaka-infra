# include common settings from parent directories recursively from the first terragrunt.hcl file
include {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/stacks/03-evaka"
}

locals {
  # Automatically load environment-level variables
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

dependency "base" {
  config_path = "../02-base"
}

inputs = {
  env                         = local.environment_vars.locals.env
  aws_account_id              = local.environment_vars.locals.aws_account_id
  aws_region                  = local.environment_vars.locals.aws_region
  evaka_infra_repository_name = local.environment_vars.locals.evaka_infra_repository_name
  name_prefix                 = try(local.environment_vars.locals.name_prefix, "evaka")

  evaka_fqdn            = try(local.environment_vars.locals.evaka_fqdn, "")
  log_retention_in_days = try(local.environment_vars.locals.log_retention_in_days, 30)

  evaka_dummy_idp_image = try(local.environment_vars.locals.evaka_dummy_idp_image, "")

  evaka_frontend_image   = local.environment_vars.locals.evaka_frontend_image
  evaka_frontend_envvars = try(local.environment_vars.locals.evaka_frontend_envvars, {})

  evaka_apigw_image   = local.environment_vars.locals.evaka_apigw_image
  evaka_apigw_envvars = try(local.environment_vars.locals.evaka_apigw_envvars, {})
  evaka_apigw_secrets = try(local.environment_vars.locals.evaka_apigw_secrets, {})

  evaka_service_image   = local.environment_vars.locals.evaka_service_image
  evaka_service_envvars = try(local.environment_vars.locals.evaka_service_envvars, {})
  evaka_service_secrets = try(local.environment_vars.locals.evaka_service_secrets, {})

  # These values comes from other stacks
  vpc_id             = dependency.base.outputs.vpc_id
  public_subnet_ids  = dependency.base.outputs.public_subnet_ids
  private_subnet_ids = dependency.base.outputs.private_subnet_ids
  allow_access_from  = local.environment_vars.locals.allow_access_from

  rds_security_group_id         = dependency.base.outputs.rds_security_group_id
  rds_database_endpoint_address = dependency.base.outputs.rds_database_endpoint_address
  rds_database_endpoint_port    = dependency.base.outputs.rds_database_endpoint_port

  evaka_db_name                          = dependency.base.outputs.evaka_db_name
  evaka_db_application_user_password_arn = dependency.base.outputs.evaka_db_application_user_password_arn
  evaka_db_migration_user_password_arn   = dependency.base.outputs.evaka_db_migration_user_password_arn
}