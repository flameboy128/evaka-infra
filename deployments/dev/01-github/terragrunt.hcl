# include common settings from parent directories recursively from the first terragrunt.hcl file
include {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/stacks/01-github"
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
  evaka_app_repository_name   = local.environment_vars.locals.evaka_app_repository_name
  name_prefix                 = try(local.environment_vars.locals.name_prefix, "evaka")
}