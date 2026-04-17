output "github_infra_role_arn" {
  value = aws_iam_role.github_actions_role_infra.arn
}

output "github_app_role_arn" {
  value = aws_iam_role.github_actions_role_app.arn
}
