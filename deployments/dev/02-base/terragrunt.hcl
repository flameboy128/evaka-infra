# include common settings from parent directories recursively from the first terragrunt.hcl file
include {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/stacks/02-base"
}

locals {
  # Automatically load environment-level variables
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

inputs = {
  env                         = local.environment_vars.locals.env
  aws_account_id              = local.environment_vars.locals.aws_account_id
  aws_region                  = local.environment_vars.locals.aws_region
  evaka_infra_repository_name = local.environment_vars.locals.evaka_infra_repository_name
  name_prefix                 = try(local.environment_vars.locals.name_prefix, "evaka")

  evaka_fqdn         = try(local.environment_vars.locals.evaka_fqdn, "")
  rds_engine_version = try(local.environment_vars.locals.rds_engine_version, "17.4")
  evaka_db_name      = try(local.environment_vars.locals.evaka_db_name, "evaka")
}