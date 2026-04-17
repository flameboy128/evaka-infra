locals {
  # Automatically load environment-level variables
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  # Extract the variables we need for easy access
  env                         = local.environment_vars.locals.env
  aws_account_id              = local.environment_vars.locals.aws_account_id
  aws_region                  = local.environment_vars.locals.aws_region
  evaka_infra_repository_name = local.environment_vars.locals.evaka_infra_repository_name
  name_prefix                 = local.environment_vars.locals.name_prefix
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket       = "${local.name_prefix}-tf-state-${local.aws_account_id}"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = local.aws_region
    encrypt      = true
    use_lockfile = true

    s3_bucket_tags = {
      environment = local.env
      repository  = local.evaka_infra_repository_name
      service     = "common"
    }
  }
}
