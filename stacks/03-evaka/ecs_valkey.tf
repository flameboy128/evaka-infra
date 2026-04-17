# Common variables
locals {
  ecs_valkey_desired_count = 1
  ecs_valkey_image         = "valkey/valkey:9.0-alpine"
  ecs_valkey_name          = join("-", [lower(var.name_prefix), "ecs-valkey"])

  ecs_valkey_envvars = {
    # FOO: "bar"
  }

  ecs_valkey_envvar_arr = [
    for name, value in local.ecs_valkey_envvars : {
      "name" : name,
      "value" : value
    }
  ]
}


# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs_valkey" {
  name              = "/ecs/${aws_ecs_cluster.evaka.name}/valkey"
  retention_in_days = var.log_retention_in_days
}


# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_exec_role_ecs_valkey" {
  name               = join("-", [lower(var.name_prefix), "ecs-task-exec-role-ecs-valkey"])
  description        = "ECS task execution role for ${local.ecs_valkey_name}"
  assume_role_policy = data.aws_iam_policy_document.assume_ecs_task_role.json
}

resource "aws_iam_role_policies_exclusive" "ecs_task_exec_role_ecs_valkey" {
  role_name    = aws_iam_role.ecs_task_exec_role_ecs_valkey.name
  policy_names = []
}

resource "aws_iam_role_policy_attachments_exclusive" "ecs_task_exec_role_ecs_valkey" {
  role_name   = aws_iam_role.ecs_task_exec_role_ecs_valkey.name
  policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
}


# ECS Task Role
resource "aws_iam_role" "ecs_valkey" {
  name               = join("-", [lower(var.name_prefix), "ecs-task-role-ecs-valkey"])
  description        = "ECS task role for ${local.ecs_valkey_name}"
  assume_role_policy = data.aws_iam_policy_document.assume_ecs_task_role.json

  depends_on = [
    aws_iam_policy.allow_ecs_exec
  ]
}
resource "aws_iam_role_policies_exclusive" "ecs_valkey" {
  role_name    = aws_iam_role.ecs_valkey.name
  policy_names = []
}
resource "aws_iam_role_policy_attachments_exclusive" "ecs_valkey" {
  role_name = aws_iam_role.ecs_valkey.name
  policy_arns = [
    aws_iam_policy.allow_ecs_exec.arn
  ]
}


# Security Group
resource "aws_security_group" "ecs_valkey" {
  name        = join("-", [lower(var.name_prefix), "ecs", "valkey"])
  description = "Security group for ${local.ecs_valkey_name} ECS service"
  vpc_id      = var.vpc_id

  # Normally, Terraform first deletes the existing security group resource and then creates a new one. When a security group is associated with a resource, the delete won't succeed. 
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = join("-", [lower(var.name_prefix), "ecs", "valkey"])
  }
}

# Allow all out
resource "aws_vpc_security_group_egress_rule" "ecs_valkey_allow_all_out_ipv4" {
  security_group_id = aws_security_group.ecs_valkey.id
  description       = "Default allow all out rule"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Allow tcp/6379 from evaka-apigw
resource "aws_vpc_security_group_ingress_rule" "ecs_valkey_allow_from_evaka_apigw" {
  security_group_id            = aws_security_group.ecs_valkey.id
  description                  = "Allow tcp/6379 (valkey) from evaka-apigw"
  referenced_security_group_id = aws_security_group.evaka_apigw.id
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
}


# ECS Task Definition
resource "aws_ecs_task_definition" "ecs_valkey" {
  family                   = "valkey"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }
  cpu                = "256"
  memory             = "512"
  execution_role_arn = aws_iam_role.ecs_task_exec_role_ecs_valkey.arn
  task_role_arn      = aws_iam_role.ecs_valkey.arn

  track_latest = true

  container_definitions = jsonencode([
    {
      name      = "valkey",
      image     = local.ecs_valkey_image
      essential = true

      linuxParameters = {
        initProcessEnabled = true
      }

      environment = local.ecs_valkey_envvar_arr

      portMappings = [
        {
          name          = "valkey"
          containerPort = 6379
          hostPort      = 6379
          protocol      = "tcp"
        }
      ]

      healthCheck = {
        command = [
          "CMD-SHELL",
          "valkey-cli -h 127.0.0.1 -t 4 ping || exit 1"
        ]
        interval    = 5
        retries     = 3
        timeout     = 5
        startPeriod = 60
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_valkey.name
          "awslogs-region"        = "${var.aws_region}"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "ecs_valkey" {
  name                   = "valkey"
  cluster                = aws_ecs_cluster.evaka.id
  task_definition        = aws_ecs_task_definition.ecs_valkey.arn
  desired_count          = local.ecs_valkey_desired_count
  launch_type            = "FARGATE"
  enable_execute_command = true
  wait_for_steady_state  = true

  deployment_circuit_breaker {
    enable   = true
    rollback = false
  }

  network_configuration {
    subnets          = [var.private_subnet_ids[0]]
    security_groups  = [aws_security_group.ecs_valkey.id]
    assign_public_ip = false
  }

  service_connect_configuration {
    enabled = true
    service {
      port_name = "valkey"
      client_alias {
        dns_name = "ecs-valkey"
        port     = 6379
      }
    }
  }
}
