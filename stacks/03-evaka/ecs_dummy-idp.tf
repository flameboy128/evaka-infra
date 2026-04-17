# Common variables
locals {
  dummy_idp_desired_count = 1
  dummy_idp_name          = join("-", [lower(var.name_prefix), "dummy-idp"])

  dummy_idp_envvars = {
    SP_ENTITY_ID : "https://${var.evaka_fqdn}/api/application/auth/saml/"
    SP_SSO_CALLBACK_URL : "https://${var.evaka_fqdn}/api/application/auth/saml/login/callback"
    SP_SLO_CALLBACK_URL : "https://${var.evaka_fqdn}/api/application/auth/saml/logout/callback"
  }

  dummy_idp_envvar_arr = [
    for name, value in local.dummy_idp_envvars : {
      "name" : name,
      "value" : value
    }
  ]
}


# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "dummy_idp" {
  count = var.evaka_dummy_idp_image != "" ? 1 : 0

  name              = "/ecs/${aws_ecs_cluster.evaka.name}/dummy-idp"
  retention_in_days = var.log_retention_in_days
}


# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_exec_role_dummy_idp" {
  count = var.evaka_dummy_idp_image != "" ? 1 : 0

  name               = join("-", [lower(var.name_prefix), "ecs-task-exec-role-dummy-idp"])
  description        = "ECS task execution role for ${local.dummy_idp_name}"
  assume_role_policy = data.aws_iam_policy_document.assume_ecs_task_role.json
}

resource "aws_iam_role_policies_exclusive" "ecs_task_exec_role_dummy_idp" {
  count = var.evaka_dummy_idp_image != "" ? 1 : 0

  role_name    = aws_iam_role.ecs_task_exec_role_dummy_idp[0].name
  policy_names = []
}

resource "aws_iam_role_policy_attachments_exclusive" "ecs_task_exec_role_dummy_idp" {
  count = var.evaka_dummy_idp_image != "" ? 1 : 0

  role_name   = aws_iam_role.ecs_task_exec_role_dummy_idp[0].name
  policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
}


# ECS Task Role
resource "aws_iam_role" "dummy_idp" {
  count = var.evaka_dummy_idp_image != "" ? 1 : 0

  name               = join("-", [lower(var.name_prefix), "ecs-task-role-dummy-idp"])
  description        = "ECS task role for ${local.dummy_idp_name}"
  assume_role_policy = data.aws_iam_policy_document.assume_ecs_task_role.json

  depends_on = [
    aws_iam_policy.allow_ecs_exec
  ]
}
resource "aws_iam_role_policies_exclusive" "dummy_idp" {
  count = var.evaka_dummy_idp_image != "" ? 1 : 0

  role_name    = aws_iam_role.dummy_idp[0].name
  policy_names = []
}
resource "aws_iam_role_policy_attachments_exclusive" "dummy_idp" {
  count = var.evaka_dummy_idp_image != "" ? 1 : 0

  role_name = aws_iam_role.dummy_idp[0].name
  policy_arns = [
    aws_iam_policy.allow_ecs_exec.arn
  ]
}


# Security Group
resource "aws_security_group" "dummy_idp" {
  count = var.evaka_dummy_idp_image != "" ? 1 : 0

  name        = join("-", [lower(var.name_prefix), "ecs", "dummy-idp"])
  description = "Security group for ${local.dummy_idp_name} ECS service"
  vpc_id      = var.vpc_id

  # Normally, Terraform first deletes the existing security group resource and then creates a new one. When a security group is associated with a resource, the delete won't succeed. 
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = join("-", [lower(var.name_prefix), "ecs", "dummy-idp"])
  }
}

# Allow all out
resource "aws_vpc_security_group_egress_rule" "dummy_idp_allow_all_out_ipv4" {
  count = var.evaka_dummy_idp_image != "" ? 1 : 0

  security_group_id = aws_security_group.dummy_idp[0].id
  description       = "Default allow all out rule"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Allow http/9090 from ALB
resource "aws_vpc_security_group_ingress_rule" "dummy_idp_allow_from_alb" {
  count = var.evaka_dummy_idp_image != "" ? 1 : 0

  security_group_id            = aws_security_group.dummy_idp[0].id
  description                  = "Allow tcp/9090 (http) from ALB"
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = 9090
  to_port                      = 9090
}

# Store image value into SSM
resource "aws_ssm_parameter" "dummy_idp_image" {
  count = var.evaka_dummy_idp_image != "" ? 1 : 0

  name  = "dummy_idp_image"
  type  = "String"
  value = var.evaka_dummy_idp_image

  lifecycle {
    ignore_changes = [value]
  }
}

data "aws_ssm_parameter" "dummy_idp_image" {
  count = var.evaka_dummy_idp_image != "" ? 1 : 0

  name = "dummy_idp_image"

  depends_on = [
    aws_ssm_parameter.dummy_idp_image[0]
  ]
}

# ECS Task Definition
resource "aws_ecs_task_definition" "dummy_idp" {
  count = var.evaka_dummy_idp_image != "" ? 1 : 0

  family                   = "dummy-idp"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }
  cpu                = "256"
  memory             = "512"
  execution_role_arn = aws_iam_role.ecs_task_exec_role_dummy_idp[0].arn
  task_role_arn      = aws_iam_role.dummy_idp[0].arn

  track_latest = true

  container_definitions = jsonencode([
    {
      name      = "dummy-idp",
      image     = data.aws_ssm_parameter.dummy_idp_image[0].insecure_value
      essential = true

      linuxParameters = {
        initProcessEnabled = true
      }

      environment = local.dummy_idp_envvar_arr

      portMappings = [
        {
          name          = "dummy-idp"
          containerPort = 9090
          hostPort      = 9090
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]

      healthCheck = {
        command = [
          "CMD-SHELL",
          "node -e \"require('http').get('http://localhost:9090/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))\""
        ]
        interval    = 5
        retries     = 3
        timeout     = 5
        startPeriod = 60
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.dummy_idp[0].name
          "awslogs-region"        = "${var.aws_region}"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "dummy_idp" {
  count = var.evaka_dummy_idp_image != "" ? 1 : 0

  name                   = "dummy-idp"
  cluster                = aws_ecs_cluster.evaka.id
  task_definition        = aws_ecs_task_definition.dummy_idp[0].arn
  desired_count          = local.dummy_idp_desired_count
  launch_type            = "FARGATE"
  enable_execute_command = true
  wait_for_steady_state  = true

  deployment_circuit_breaker {
    enable   = true
    rollback = false
  }

  network_configuration {
    subnets          = [var.private_subnet_ids[0]]
    security_groups  = [aws_security_group.dummy_idp[0].id]
    assign_public_ip = false
  }

  service_connect_configuration {
    enabled = true
    service {
      port_name = "dummy-idp"
      client_alias {
        dns_name = "dummy-idp"
        port     = 9090
      }
    }
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.dummy_idp[0].arn
    container_name   = "dummy-idp"
    container_port   = 9090
  }
}
