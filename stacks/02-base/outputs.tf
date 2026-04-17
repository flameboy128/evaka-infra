output "r53_hosted_zone_name" {
  value = aws_route53_zone.evaka.name
}

output "r53_nameservers" {
  value = aws_route53_zone.evaka.name_servers
}

output "aws_region" {
  value = var.aws_region
}

output "vpc_id" {
  value = aws_vpc.evaka.id
}

output "private_subnet_ids" {
  value = [aws_subnet.private-1a.id, aws_subnet.private-1b.id]
}

output "public_subnet_ids" {
  value = [aws_subnet.public-1a.id, aws_subnet.public-1b.id]
}

output "rds_database_endpoint_address" {
  value = aws_rds_cluster.evaka_rds.endpoint
}

output "rds_database_endpoint_port" {
  value = aws_rds_cluster.evaka_rds.port
}

output "rds_master_password_secret_arn" {
  value = aws_secretsmanager_secret.evaka_rds_master.arn
}

output "rds_security_group_id" {
  value = aws_security_group.evaka_rds.id
}

output "ecr_host" {
  value = split("/", aws_ecr_repository.evaka_service.repository_url)[0]
}

output "ecr_repository_evaka_service_url" {
  value = aws_ecr_repository.evaka_service.repository_url
}

output "ec2_bastion_instance_id" {
  value = aws_instance.ec2_bastion.id
}

output "evaka_db_name" {
  value = aws_rds_cluster.evaka_rds.database_name
}

output "evaka_db_migration_user_password_arn" {
  value = aws_secretsmanager_secret_version.evaka_rds_migration.arn
}

output "evaka_db_application_user_password_arn" {
  value = aws_secretsmanager_secret_version.evaka_rds_application.arn
}

output "backup_resources" {
  value = [aws_rds_cluster.evaka_rds.arn]
}
