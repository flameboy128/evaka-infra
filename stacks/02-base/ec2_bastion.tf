# EC2 Bastion host/jump-box for accessing and debugging RDS/Database and services

locals {
  ec2_bastion_name = join("-", [lower(var.name_prefix), "ec2-bastion"])
}


# Security Group
resource "aws_security_group" "ec2_bastion" {
  name        = local.ec2_bastion_name
  description = "Security group for ${local.ec2_bastion_name} EC2 instance"
  vpc_id      = aws_vpc.evaka.id

  # Normally, Terraform first deletes the existing security group resource and then creates a new one. When a security group is associated with a resource, the delete won't succeed. 
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = local.ec2_bastion_name
  }
}

resource "aws_vpc_security_group_egress_rule" "ec2_bastion_allow_all_out_ipv4" {
  security_group_id = aws_security_group.ec2_bastion.id
  description       = "Default allow all out rule"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Allow access to RDS
resource "aws_vpc_security_group_ingress_rule" "evaka_rds_allow_psql_from_ec2_bastion" {
  security_group_id            = aws_security_group.evaka_rds.id
  description                  = "Allow tcp/5432 (psql) from ${local.ec2_bastion_name} EC2 instance"
  referenced_security_group_id = aws_security_group.ec2_bastion.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_iam_instance_profile" "ec2_bastion" {
  name = aws_iam_role.ec2_bastion.name
  role = aws_iam_role.ec2_bastion.name
}

resource "aws_iam_role" "ec2_bastion" {
  name        = "${local.ec2_bastion_name}-role"
  description = "IAM role/Instance profile for ${local.ec2_bastion_name} EC2 instance"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policies_exclusive" "ec2_bastion" {
  role_name    = aws_iam_role.ec2_bastion.name
  policy_names = []
}

resource "aws_iam_role_policy_attachments_exclusive" "ec2_bastion" {
  role_name   = aws_iam_role.ec2_bastion.name
  policy_arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
}

data "aws_ami" "amzn-linux-2023-ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "ec2_bastion" {
  ami                    = data.aws_ami.amzn-linux-2023-ami.id
  instance_type          = "t3.nano"
  iam_instance_profile   = aws_iam_instance_profile.ec2_bastion.name
  subnet_id              = aws_subnet.private-1a.id
  vpc_security_group_ids = [aws_security_group.ec2_bastion.id]

  credit_specification {
    cpu_credits = "standard"
  }

  root_block_device {
    encrypted = true
  }

  user_data = <<-EOF
  #!/bin/bash
  dnf upgrade
  dnf install -y postgresql17
  EOF

  user_data_replace_on_change = true

  tags = {
    Name       = local.ec2_bastion_name
    PatchGroup = local.ec2_bastion_name
  }
  volume_tags = {
    Name = local.ec2_bastion_name
  }
}

resource "aws_ssm_maintenance_window" "ec2_bastion" {
  allow_unassociated_targets = false
  name                       = "${local.ec2_bastion_name}-maintenance-window"
  description                = "${local.ec2_bastion_name}-maintenance-window"
  schedule                   = "cron(0 30 3 ? * * *)"
  schedule_timezone          = "Europe/Helsinki"
  duration                   = 1
  cutoff                     = 0
}

resource "aws_ssm_maintenance_window_target" "ec2_bastion" {
  window_id     = aws_ssm_maintenance_window.ec2_bastion.id
  name          = local.ec2_bastion_name
  description   = local.ec2_bastion_name
  resource_type = "INSTANCE"
  targets {
    key    = "tag:PatchGroup"
    values = [local.ec2_bastion_name]
  }
}

resource "aws_ssm_maintenance_window_task" "ec2_bastion_patch" {
  name      = "AWS-RunPatchBaseline"
  task_arn  = "AWS-RunPatchBaseline"
  task_type = "RUN_COMMAND"
  window_id = aws_ssm_maintenance_window.ec2_bastion.id
  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.ec2_bastion.id]
  }
  max_concurrency = 1
  max_errors      = 1
  priority        = 1
  task_invocation_parameters {
    run_command_parameters {
      timeout_seconds = 1800
      parameter {
        name   = "Operation"
        values = ["Install"]
      }
      parameter {
        name   = "StepTimeoutSeconds"
        values = ["1800"]
      }
      parameter {
        name   = "RebootOption"
        values = ["RebootIfNeeded"]
      }
    }
  }
}
