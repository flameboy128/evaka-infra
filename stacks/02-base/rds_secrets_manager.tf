# Secrets Manager entry for RDS Master credentials
resource "aws_secretsmanager_secret" "evaka_rds_master" {
  name                    = "${local.evaka_rds_name}-rds_master"
  description             = "Password for rds_master user in ${local.evaka_rds_name}"
  recovery_window_in_days = 0
}

ephemeral "aws_secretsmanager_random_password" "evaka_rds_master" {
  exclude_punctuation        = true
  password_length            = 34
  require_each_included_type = true
}

resource "aws_secretsmanager_secret_version" "evaka_rds_master" {
  secret_id                = aws_secretsmanager_secret.evaka_rds_master.id
  secret_string_wo         = ephemeral.aws_secretsmanager_random_password.evaka_rds_master.random_password
  secret_string_wo_version = 1
}

ephemeral "aws_secretsmanager_secret_version" "evaka_rds_master" {
  secret_id = aws_secretsmanager_secret_version.evaka_rds_master.secret_id
}

# Secrets Manager entry for evaka_application RDS credentials
resource "aws_secretsmanager_secret" "evaka_rds_application" {
  name                    = "${local.evaka_rds_name}-evaka_application"
  description             = "Password for evaka_application user in ${local.evaka_rds_name}"
  recovery_window_in_days = 0
}

ephemeral "aws_secretsmanager_random_password" "evaka_rds_application" {
  exclude_punctuation        = true
  password_length            = 34
  require_each_included_type = true
}

resource "aws_secretsmanager_secret_version" "evaka_rds_application" {
  secret_id                = aws_secretsmanager_secret.evaka_rds_application.id
  secret_string_wo         = ephemeral.aws_secretsmanager_random_password.evaka_rds_application.random_password
  secret_string_wo_version = 1
}

ephemeral "aws_secretsmanager_secret_version" "evaka_rds_application" {
  secret_id = aws_secretsmanager_secret_version.evaka_rds_application.secret_id
}

# Secrets Manager entry for evaka_migration RDS credentials
resource "aws_secretsmanager_secret" "evaka_rds_migration" {
  name                    = "${local.evaka_rds_name}-evaka_migration"
  description             = "Password for evaka_migration user in ${local.evaka_rds_name}"
  recovery_window_in_days = 0
}

ephemeral "aws_secretsmanager_random_password" "evaka_rds_migration" {
  exclude_punctuation        = true
  password_length            = 34
  require_each_included_type = true
}

resource "aws_secretsmanager_secret_version" "evaka_rds_migration" {
  secret_id                = aws_secretsmanager_secret.evaka_rds_migration.id
  secret_string_wo         = ephemeral.aws_secretsmanager_random_password.evaka_rds_migration.random_password
  secret_string_wo_version = 1
}

ephemeral "aws_secretsmanager_secret_version" "evaka_rds_migration" {
  secret_id = aws_secretsmanager_secret_version.evaka_rds_migration.secret_id
}
