# Backup Vault
resource "aws_backup_vault" "main_vault" {
  name = join("-", [lower(var.name_prefix), "backup-vault"])
}

# Backup Plan
resource "aws_backup_plan" "backup_plan" {
  name = join("-", [lower(var.name_prefix), "backup-plan"])

  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.main_vault.name
    schedule          = "cron(0 0 * * ? *)"

    lifecycle {
      delete_after = 3
    }
  }

  rule {
    rule_name         = "weekly-backup"
    target_vault_name = aws_backup_vault.main_vault.name
    schedule          = "cron(0 0 ? * SUN *)"

    lifecycle {
      delete_after = 30
    }
  }
}

# Backup resource selection
resource "aws_backup_selection" "main_selection" {
  iam_role_arn = aws_iam_role.backup_role.arn
  name         = "main_selection"
  plan_id      = aws_backup_plan.backup_plan.id

  resources = var.backup_resources
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }

}

# Backup role
resource "aws_iam_role" "backup_role" {
  name               = join("-", [lower(var.name_prefix), "backup-role"])
  description        = "Role for AWS Backup"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# Policy Attachments
resource "aws_iam_role_policy_attachment" "backup_service_role_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.backup_role.name
}

resource "aws_iam_role_policy_attachment" "backup_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AWSBackupServiceRolePolicyForS3Backup"
  role       = aws_iam_role.backup_role.name
}
