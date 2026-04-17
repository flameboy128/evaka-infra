# include common settings from parent directories recursively from the first terragrunt.hcl file
include {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/stacks/04-backup"
}

locals {
  # Automatically load environment-level variables
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

dependency "base" {
  config_path = "../02-base"
}

dependency "evaka" {
  config_path = "../03-evaka"
}

inputs = {
  env                         = local.environment_vars.locals.env
  aws_account_id              = local.environment_vars.locals.aws_account_id
  aws_region                  = local.environment_vars.locals.aws_region
  evaka_infra_repository_name = local.environment_vars.locals.evaka_infra_repository_name
  name_prefix                 = try(local.environment_vars.locals.name_prefix, "evaka")
  backup_resources            = concat(dependency.base.outputs.backup_resources, dependency.evaka.outputs.backup_resources)
}