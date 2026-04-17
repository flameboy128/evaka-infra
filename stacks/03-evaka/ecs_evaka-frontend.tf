# Common variables
locals {
  evaka_frontend_desired_count = 1
  evaka_frontend_name          = join("-", [lower(var.name_prefix), "frontend"])
}


# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "evaka_frontend" {
  name              = "/ecs/${aws_ecs_cluster.evaka.name}/evaka-frontend"
  retention_in_days = var.log_retention_in_days
}


# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_exec_role_evaka_frontend" {
  name               = join("-", [lower(var.name_prefix), "ecs-task-exec-role-evaka-frontend"])
  description        = "ECS task execution role for ${local.evaka_frontend_name}"
  assume_role_policy = data.aws_iam_policy_document.assume_ecs_task_role.json
}

resource "aws_iam_role_policies_exclusive" "ecs_task_exec_role_evaka_frontend" {
  role_name    = aws_iam_role.ecs_task_exec_role_evaka_frontend.name
  policy_names = []
}

resource "aws_iam_role_policy_attachments_exclusive" "ecs_task_exec_role_evaka_frontend" {
  role_name   = aws_iam_role.ecs_task_exec_role_evaka_frontend.name
  policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
}


# ECS Task Role
resource "aws_iam_role" "evaka_frontend" {
  name               = local.evaka_frontend_name
  description        = "ECS task role for ${local.evaka_frontend_name}"
  assume_role_policy = data.aws_iam_policy_document.assume_ecs_task_role.json

  depends_on = [
    aws_iam_policy.allow_ecs_exec
  ]
}
resource "aws_iam_role_policies_exclusive" "evaka_frontend" {
  role_name    = aws_iam_role.evaka_frontend.name
  policy_names = []
}
resource "aws_iam_role_policy_attachments_exclusive" "evaka_frontend" {
  role_name   = aws_iam_role.evaka_frontend.name
  policy_arns = [aws_iam_policy.allow_ecs_exec.arn]
}


# Security Group
resource "aws_security_group" "evaka_frontend" {
  name        = local.evaka_frontend_name
  description = "Security group for ${local.evaka_frontend_name} ECS service"
  vpc_id      = var.vpc_id

  # Normally, Terraform first deletes the existing security group resource and then creates a new one. When a security group is associated with a resource, the delete won't succeed. 
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = local.evaka_frontend_name
  }
}

# Allow all out
resource "aws_vpc_security_group_egress_rule" "evaka_frontend_allow_all_out_ipv4" {
  security_group_id = aws_security_group.evaka_frontend.id
  description       = "Default allow all out rule"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Allow http/8080 from ALB
resource "aws_vpc_security_group_ingress_rule" "evaka_frontend_allow_from_alb" {
  security_group_id            = aws_security_group.evaka_frontend.id
  description                  = "Allow http/8080 from ALB"
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
}

# Store image value into SSM
resource "aws_ssm_parameter" "evaka_frontend_image" {
  name  = "evaka_frontend_image"
  type  = "String"
  value = var.evaka_frontend_image

  lifecycle {
    ignore_changes = [value]
  }
}

data "aws_ssm_parameter" "evaka_frontend_image" {
  name = "evaka_frontend_image"

  depends_on = [
    aws_ssm_parameter.evaka_frontend_image
  ]
}

# ECS Task Definition
resource "aws_ecs_task_definition" "evaka_frontend" {
  family                   = "evaka-frontend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }
  cpu                = "256"
  memory             = "512"
  execution_role_arn = aws_iam_role.ecs_task_exec_role_evaka_frontend.arn
  task_role_arn      = aws_iam_role.evaka_frontend.arn

  track_latest = true

  container_definitions = jsonencode([
    {
      name      = "evaka-frontend"
      image     = data.aws_ssm_parameter.evaka_frontend_image.insecure_value
      essential = true

      linuxParameters = {
        initProcessEnabled = true
      }

      environment = [
        for name, value in var.evaka_frontend_envvars : {
          "name" : name,
          "value" : value
      }]

      portMappings = [
        {
          name          = "evaka-frontend"
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]

      healthCheck = {
        command = [
          "CMD-SHELL",
          "bash -c \"exec 3<>/dev/tcp/localhost/8080 && echo -e 'GET /health HTTP/1.0\\r\\nHost: localhost\\r\\n\\r\\n' >&3 && head -1 <&3 | grep -q '200'\""
        ]
        interval    = 5
        retries     = 3
        timeout     = 5
        startPeriod = 60
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.evaka_frontend.name
          "awslogs-region"        = "${var.aws_region}"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "evaka_frontend" {
  name                   = "evaka-frontend"
  cluster                = aws_ecs_cluster.evaka.id
  task_definition        = aws_ecs_task_definition.evaka_frontend.arn
  desired_count          = local.evaka_frontend_desired_count
  launch_type            = "FARGATE"
  enable_execute_command = true
  wait_for_steady_state  = true

  deployment_circuit_breaker {
    enable   = true
    rollback = false
  }

  network_configuration {
    subnets          = [var.private_subnet_ids[0]]
    security_groups  = [aws_security_group.evaka_frontend.id]
    assign_public_ip = false
  }

  service_connect_configuration {
    enabled = true
    service {
      port_name = "evaka-frontend"
      client_alias {
        dns_name = "evaka-frontend"
        port     = 8080
      }
    }
  }

  depends_on = [
    aws_ecs_service.evaka_apigw
  ]

  load_balancer {
    target_group_arn = aws_lb_target_group.evaka_frontend.arn
    container_name   = "evaka-frontend"
    container_port   = 8080
  }
}
