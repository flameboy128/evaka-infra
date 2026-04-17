output "evaka_url" {
  value       = "https://${var.evaka_fqdn}"
  description = "Evaka URL"
}

output "evaka_employee_url" {
  value       = "https://${var.evaka_fqdn}/employee"
  description = "Evaka URL for employees"
}

output "backup_resources" {
  value = values(aws_s3_bucket.evaka)[*].arn
}
