locals {
  evaka_rds_name = join("-", [lower(var.name_prefix), "rds"])
}


# Security Group for RDS
resource "aws_security_group" "evaka_rds" {
  name        = local.evaka_rds_name
  description = "Security group for ${local.evaka_rds_name} RDS"
  vpc_id      = aws_vpc.evaka.id

  # Normally, Terraform first deletes the existing security group resource and then creates a new one. When a security group is associated with a resource, the delete won't succeed. 
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = local.evaka_rds_name
  }
}

resource "aws_vpc_security_group_egress_rule" "evaka_rds_allow_all_out_ipv4" {
  security_group_id = aws_security_group.evaka_rds.id
  description       = "Default allow all out rule"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_db_subnet_group" "evaka_rds" {
  name       = local.evaka_rds_name
  subnet_ids = [aws_subnet.private-1a.id, aws_subnet.private-1b.id]
}

# RDS Aurora PostgreSQL cluster
resource "aws_rds_cluster" "evaka_rds" {
  cluster_identifier = local.evaka_rds_name
  engine             = "aurora-postgresql"
  engine_mode        = "provisioned"
  engine_version     = var.rds_engine_version
  storage_encrypted  = true
  # manage_master_user_password = true
  database_name              = var.evaka_db_name
  master_username            = "rds_master"
  master_password_wo         = ephemeral.aws_secretsmanager_secret_version.evaka_rds_master.secret_string
  master_password_wo_version = aws_secretsmanager_secret_version.evaka_rds_master.secret_string_wo_version

  apply_immediately     = true
  enable_http_endpoint  = true
  skip_final_snapshot   = true
  copy_tags_to_snapshot = true

  db_subnet_group_name   = aws_db_subnet_group.evaka_rds.name
  vpc_security_group_ids = [aws_security_group.evaka_rds.id]

  serverlessv2_scaling_configuration {
    max_capacity             = 4.0
    min_capacity             = 0.0
    seconds_until_auto_pause = 3600
  }
}

resource "aws_rds_cluster_instance" "evaka_rds_01" {
  identifier         = "${local.evaka_rds_name}-01"
  cluster_identifier = aws_rds_cluster.evaka_rds.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.evaka_rds.engine
  engine_version     = aws_rds_cluster.evaka_rds.engine_version
  availability_zone  = aws_subnet.private-1a.availability_zone
}
