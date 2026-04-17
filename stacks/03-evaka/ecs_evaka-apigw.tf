# Common variables
locals {
  evaka_apigw_desired_count = 1
  evaka_apigw_name          = join("-", [lower(var.name_prefix), "apigw"])
}


# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "evaka_apigw" {
  name              = "/ecs/${aws_ecs_cluster.evaka.name}/evaka-apigw"
  retention_in_days = var.log_retention_in_days
}

# Custom ECS Task Execution Role for accessing Secrets Manager
resource "aws_iam_role" "ecs_task_exec_role_evaka_apigw" {
  name               = join("-", [lower(var.name_prefix), "ecs-task-exec-role-evaka-apigw"])
  description        = "ECS task execution role for ${local.evaka_apigw_name}"
  assume_role_policy = data.aws_iam_policy_document.assume_ecs_task_role.json
}
resource "aws_iam_role_policy" "evaka_apigw_secrets_manager" {
  name = "secrets-manager"
  role = aws_iam_role.ecs_task_exec_role_evaka_apigw.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
        ]
        Effect = "Allow"
        Resource = [
          aws_secretsmanager_secret_version.evaka_apigw_citizen_cookie_secret.arn,
          aws_secretsmanager_secret_version.evaka_apigw_employee_cookie_secret.arn
        ]
      }
    ]
  })
}
resource "aws_iam_role_policies_exclusive" "ecs_task_exec_role_evaka_apigw" {
  role_name    = aws_iam_role.ecs_task_exec_role_evaka_apigw.name
  policy_names = [aws_iam_role_policy.evaka_apigw_secrets_manager.name]
}
resource "aws_iam_role_policy_attachments_exclusive" "ecs_task_exec_role_evaka_apigw" {
  role_name   = aws_iam_role.ecs_task_exec_role_evaka_apigw.name
  policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
}


# ECS Task Role
resource "aws_iam_role" "evaka_apigw" {
  name               = join("-", [lower(var.name_prefix), "ecs-task-role-evaka-apigw"])
  description        = "ECS task role for ${local.evaka_apigw_name}"
  assume_role_policy = data.aws_iam_policy_document.assume_ecs_task_role.json

  depends_on = [
    aws_iam_policy.allow_ecs_exec
  ]
}
resource "aws_iam_role_policy" "evaka_apigw_s3_deployment" {
  name = "s3-deployment-bucket"
  role = aws_iam_role.evaka_apigw.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListDeploymentBucket"
        Action   = ["s3:ListBucket"]
        Effect   = "Allow"
        Resource = [aws_s3_bucket.evaka["deployment"].arn]
      },
      {
        Sid      = "GetDeploymentObjects"
        Action   = ["s3:GetObject"]
        Effect   = "Allow"
        Resource = ["${aws_s3_bucket.evaka["deployment"].arn}/*"]
      }
    ]
  })
}
resource "aws_iam_role_policies_exclusive" "evaka_apigw" {
  role_name    = aws_iam_role.evaka_apigw.name
  policy_names = [aws_iam_role_policy.evaka_apigw_s3_deployment.name]
}
resource "aws_iam_role_policy_attachments_exclusive" "evaka_apigw" {
  role_name   = aws_iam_role.evaka_apigw.name
  policy_arns = [aws_iam_policy.allow_ecs_exec.arn]
}


# Security Group
resource "aws_security_group" "evaka_apigw" {
  name        = join("-", [lower(var.name_prefix), "ecs", "apigw"])
  description = "Security group for ${local.evaka_apigw_name} ECS service"
  vpc_id      = var.vpc_id

  # Normally, Terraform first deletes the existing security group resource and then creates a new one. When a security group is associated with a resource, the delete won't succeed. 
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = join("-", [lower(var.name_prefix), "ecs", "apigw"])
  }
}

# Allow all out
resource "aws_vpc_security_group_egress_rule" "evaka_apigw_allow_all_out_ipv4" {
  security_group_id = aws_security_group.evaka_apigw.id
  description       = "Default allow all out rule"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Allow http/3000 from evaka-frontend
resource "aws_vpc_security_group_ingress_rule" "evaka_apigw_allow_from_evaka_frontend" {
  security_group_id            = aws_security_group.evaka_apigw.id
  description                  = "Allow tcp/3000 (http) from evaka-frontend"
  referenced_security_group_id = aws_security_group.evaka_frontend.id
  from_port                    = 3000
  to_port                      = 3000
  ip_protocol                  = "tcp"
}


# Discovery Service using private Route53 (frontend can't use hosts-file)
resource "aws_service_discovery_service" "evaka_apigw" {
  name        = "apigw"
  description = "service discovery for ${local.evaka_apigw_name}"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.evaka.id
    dns_records {
      ttl  = 10
      type = "A"
    }
  }
}

# Store image value into SSM
resource "aws_ssm_parameter" "evaka_apigw_image" {
  name  = "evaka_apigw_image"
  type  = "String"
  value = var.evaka_apigw_image

  lifecycle {
    ignore_changes = [value]
  }
}

data "aws_ssm_parameter" "evaka_apigw_image" {
  name = "evaka_apigw_image"

  depends_on = [
    aws_ssm_parameter.evaka_apigw_image
  ]
}

# Cookie secrets
resource "aws_secretsmanager_secret" "evaka_apigw_citizen_cookie_secret" {
  name                    = join("-", [lower(var.name_prefix), "evaka-apigw", "citizen-cookie-secret"])
  description             = "Evaka apigw citizen cookie secret"
  recovery_window_in_days = 0
}
ephemeral "aws_secretsmanager_random_password" "evaka_apigw_citizen_cookie_secret" {
  exclude_punctuation        = true
  password_length            = 20
  require_each_included_type = true
}
resource "aws_secretsmanager_secret_version" "evaka_apigw_citizen_cookie_secret" {
  secret_id                = aws_secretsmanager_secret.evaka_apigw_citizen_cookie_secret.id
  secret_string_wo         = ephemeral.aws_secretsmanager_random_password.evaka_apigw_citizen_cookie_secret.random_password
  secret_string_wo_version = 1
}

resource "aws_secretsmanager_secret" "evaka_apigw_employee_cookie_secret" {
  name                    = join("-", [lower(var.name_prefix), "evaka-apigw", "employee-cookie-secret"])
  description             = "Evaka apigw employee cookie secret"
  recovery_window_in_days = 0
}
ephemeral "aws_secretsmanager_random_password" "evaka_apigw_employee_cookie_secret" {
  exclude_punctuation        = true
  password_length            = 20
  require_each_included_type = true
}
resource "aws_secretsmanager_secret_version" "evaka_apigw_employee_cookie_secret" {
  secret_id                = aws_secretsmanager_secret.evaka_apigw_employee_cookie_secret.id
  secret_string_wo         = ephemeral.aws_secretsmanager_random_password.evaka_apigw_employee_cookie_secret.random_password
  secret_string_wo_version = 1
}

# ECS Task Definition
resource "aws_ecs_task_definition" "evaka_apigw" {
  family                   = "evaka-apigw"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }
  cpu                = "256"
  memory             = "512"
  execution_role_arn = aws_iam_role.ecs_task_exec_role_evaka_apigw.arn
  task_role_arn      = aws_iam_role.evaka_apigw.arn

  track_latest = true

  container_definitions = jsonencode([
    {
      name      = "evaka-apigw"
      image     = data.aws_ssm_parameter.evaka_apigw_image.insecure_value
      essential = true

      linuxParameters = {
        initProcessEnabled = true
      }

      environment = concat(
        [{
          "name" : "DEPLOYMENT_BUCKET",
          "value" : aws_s3_bucket.evaka["deployment"].id
        }],
        [
          for name, value in var.evaka_apigw_envvars : {
            "name" : name,
            "value" : value

        }]
      )

      secrets = [
        {
          name      = "CITIZEN_COOKIE_SECRET"
          valueFrom = aws_secretsmanager_secret_version.evaka_apigw_citizen_cookie_secret.arn
        },
        {
          name      = "EMPLOYEE_COOKIE_SECRET"
          valueFrom = aws_secretsmanager_secret_version.evaka_apigw_employee_cookie_secret.arn
        }
      ]

      portMappings = [
        {
          name          = "evaka-apigw"
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]

      healthCheck = {
        command = [
          "CMD-SHELL",
          "node -e \"require('http').get('http://localhost:3000/health', (r) => { r.resume(); process.exit(r.statusCode === 200 ? 0 : 1) }).on('error', () => process.exit(1))\""
        ]
        interval    = 5
        retries     = 3
        timeout     = 5
        startPeriod = 120
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.evaka_apigw.name
          "awslogs-region"        = "${var.aws_region}"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "evaka_apigw" {
  name                   = "evaka-apigw"
  cluster                = aws_ecs_cluster.evaka.id
  task_definition        = aws_ecs_task_definition.evaka_apigw.arn
  desired_count          = local.evaka_apigw_desired_count
  launch_type            = "FARGATE"
  enable_execute_command = true
  wait_for_steady_state  = true

  deployment_circuit_breaker {
    enable   = true
    rollback = false
  }

  network_configuration {
    subnets          = [var.private_subnet_ids[0]]
    security_groups  = [aws_security_group.evaka_apigw.id]
    assign_public_ip = false
  }

  service_connect_configuration {
    enabled = true
    service {
      port_name = "evaka-apigw"
      client_alias {
        dns_name = "evaka-apigw"
        port     = 3000
      }
    }
  }

  service_registries {
    registry_arn = aws_service_discovery_service.evaka_apigw.arn
  }

  depends_on = [
    aws_ecs_service.ecs_valkey,
    aws_ecs_service.evaka_service,
    aws_ecs_service.dummy_idp,
    aws_s3_object.evaka_apigw_ad_saml_private_cert,
    aws_s3_object.evaka_apigw_ad_saml_public_cert,
    aws_s3_object.evaka_apigw_jwt_private_key,
    aws_s3_object.evaka_apigw_sfi_saml_private_cert,
    aws_s3_object.evaka_apigw_sfi_saml_public_cert,
  ]
}
