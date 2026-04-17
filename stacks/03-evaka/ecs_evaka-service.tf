# Common variables
locals {
  evaka_service_desired_count = 1
  evaka_service_name          = join("-", [lower(var.name_prefix), "service"])
  evaka_service_secret_arns   = [for k, v in var.evaka_service_secrets : v]
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "evaka_service" {
  name              = "/ecs/${aws_ecs_cluster.evaka.name}/evaka-service"
  retention_in_days = var.log_retention_in_days
}

# Custom ECS Task Execution Role for accessing Secrets Manager
resource "aws_iam_role" "ecs_task_exec_role_evaka_service" {
  name               = join("-", [lower(var.name_prefix), "ecs-task-exec-role-evaka-service"])
  description        = "ECS task execution role for ${local.evaka_service_name}"
  assume_role_policy = data.aws_iam_policy_document.assume_ecs_task_role.json
}
resource "aws_iam_role_policy" "evaka_service_secrets_manager" {
  name = "secrets-manager"
  role = aws_iam_role.ecs_task_exec_role_evaka_service.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
        ]
        Effect = "Allow"
        Resource = concat(
          [
            var.evaka_db_application_user_password_arn,
            var.evaka_db_migration_user_password_arn
          ],
          local.evaka_service_secret_arns
        )
      }
    ]
  })
}
resource "aws_iam_role_policies_exclusive" "ecs_task_exec_role_evaka_service" {
  role_name    = aws_iam_role.ecs_task_exec_role_evaka_service.name
  policy_names = [aws_iam_role_policy.evaka_service_secrets_manager.name]
}
resource "aws_iam_role_policy_attachments_exclusive" "ecs_task_exec_role_evaka_service" {
  role_name   = aws_iam_role.ecs_task_exec_role_evaka_service.name
  policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
}


# ECS Task Role
resource "aws_iam_role" "evaka_service" {
  name               = join("-", [lower(var.name_prefix), "ecs-task-role-evaka-service"])
  description        = "ECS task role for ${local.evaka_service_name}"
  assume_role_policy = data.aws_iam_policy_document.assume_ecs_task_role.json

  depends_on = [
    aws_iam_policy.allow_ecs_exec
  ]
}
resource "aws_iam_role_policy" "evaka_service_s3-buckets" {
  name = "s3-buckets"
  role = aws_iam_role.evaka_service.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListObjectsInBucket",
        Action = ["s3:ListBucket"]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.evaka["deployment"].arn,
          aws_s3_bucket.evaka["decisions"].arn,
          aws_s3_bucket.evaka["fee-decisions"].arn,
          aws_s3_bucket.evaka["data"].arn,
          aws_s3_bucket.evaka["attachments"].arn,
          aws_s3_bucket.evaka["voucher-value-decisions"].arn,
          aws_s3_bucket.evaka["invoices"].arn
        ]
      },
      {
        Sid      = "AllowGetObjects",
        Action   = ["s3:GetObject"]
        Effect   = "Allow"
        Resource = ["${aws_s3_bucket.evaka["deployment"].arn}/*"]
      },
      {
        Sid    = "AllObjectActions",
        Action = ["s3:*Object"]
        Effect = "Allow"
        Resource = [
          "${aws_s3_bucket.evaka["decisions"].arn}/*",
          "${aws_s3_bucket.evaka["fee-decisions"].arn}/*",
          "${aws_s3_bucket.evaka["data"].arn}/*",
          "${aws_s3_bucket.evaka["attachments"].arn}/*",
          "${aws_s3_bucket.evaka["voucher-value-decisions"].arn}/*",
          "${aws_s3_bucket.evaka["invoices"].arn}/*"
        ]
      }
    ]
  })
}
resource "aws_iam_role_policies_exclusive" "evaka_service" {
  role_name = aws_iam_role.evaka_service.name
  policy_names = [
    aws_iam_role_policy.evaka_service_s3-buckets.name,
  ]
}
resource "aws_iam_role_policy_attachments_exclusive" "evaka_service" {
  role_name   = aws_iam_role.evaka_service.name
  policy_arns = [aws_iam_policy.allow_ecs_exec.arn]
}


# Security Group
resource "aws_security_group" "evaka_service" {
  name        = join("-", [lower(var.name_prefix), "ecs", "service"])
  description = "Security group for ${local.evaka_service_name} ECS service"
  vpc_id      = var.vpc_id

  # Normally, Terraform first deletes the existing security group resource and then creates a new one. When a security group is associated with a resource, the delete won't succeed. 
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = join("-", [lower(var.name_prefix), "ecs", "service"])
  }
}

# Allow all out
resource "aws_vpc_security_group_egress_rule" "evaka_service_allow_all_out_ipv4" {
  security_group_id = aws_security_group.evaka_service.id
  description       = "Default allow all out rule"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Allow http/8888 from evaka-apigw
resource "aws_vpc_security_group_ingress_rule" "evaka_service_allow_from_evaka_apigw" {
  security_group_id            = aws_security_group.evaka_service.id
  description                  = "Allow tcp/8888 (http) from evaka-apigw"
  referenced_security_group_id = aws_security_group.evaka_apigw.id
  from_port                    = 8888
  to_port                      = 8888
  ip_protocol                  = "tcp"
}

# Add rule to RDS Security Group
resource "aws_vpc_security_group_ingress_rule" "evaka_service_allow_to_rds_from_evaka_service" {
  security_group_id            = var.rds_security_group_id
  description                  = "Allow tcp/5432 (psql) from evaka-service"
  referenced_security_group_id = aws_security_group.evaka_service.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

# Store image value into SSM
resource "aws_ssm_parameter" "evaka_service_image" {
  name  = "evaka_service_image"
  type  = "String"
  value = var.evaka_service_image

  lifecycle {
    ignore_changes = [value]
  }
}

data "aws_ssm_parameter" "evaka_service_image" {
  name = "evaka_service_image"

  depends_on = [
    aws_ssm_parameter.evaka_service_image
  ]
}

# ECS Task Definition
resource "aws_ecs_task_definition" "evaka_service" {
  family                   = "evaka-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }
  cpu                = "1024"
  memory             = "2048"
  execution_role_arn = aws_iam_role.ecs_task_exec_role_evaka_service.arn
  task_role_arn      = aws_iam_role.evaka_service.arn

  track_latest = true

  volume {
    name = "shared-config"
  }

  container_definitions = jsonencode([
    {
      name      = "db-wait"
      image     = "postgres:17-alpine"
      essential = false

      command = [
        "sh", "-c",
        "echo 'Waiting for database...' && until pg_isready -h ${var.rds_database_endpoint_address} -p ${var.rds_database_endpoint_port}; do sleep 3; done && echo 'Database is ready'"
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.evaka_service.name
          "awslogs-region"        = "${var.aws_region}"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    },
    {
      name      = "dev-data-loader"
      image     = "postgres:17-alpine"
      essential = false

      dependsOn = [
        {
          containerName = "evaka-service"
          condition     = "HEALTHY"
        }
      ]

      environment = [
        {
          name  = "PGHOST"
          value = var.rds_database_endpoint_address
        },
        {
          name  = "PGPORT"
          value = var.rds_database_endpoint_port
        },
        {
          name  = "PGDATABASE"
          value = var.evaka_db_name
        },
        {
          name  = "PGUSER"
          value = "evaka_migration"
        }
      ]

      secrets = [
        {
          name      = "PGPASSWORD"
          valueFrom = var.evaka_db_migration_user_password_arn
        }
      ]

      mountPoints = [
        {
          sourceVolume  = "shared-config"
          containerPath = "/config"
          readOnly      = true
        }
      ]

      command = [
        "sh", "-c",
        join(" ", [
          "if [ \"$(psql -tAc \"SELECT count(*) FROM care_area\")\" = \"0\" ]; then",
          "echo 'Loading dev data...' &&",
          "echo \"file: dev-data.sql\" && psql -f /config/dev-data/dev-data.sql &&",
          "echo \"file: service-need-options.sql\" && psql -f /config/dev-data/service-need-options.sql &&",
          "echo \"file: employees.sql\" && psql -f /config/dev-data/employees.sql &&",
          "echo \"file: preschool-terms.sql\" && psql -f /config/dev-data/preschool-terms.sql &&",
          "echo \"file: club-terms.sql\" && psql -f /config/dev-data/club-terms.sql &&",
          "echo 'Dev data loaded';",
          "else echo 'Dev data already exists (SELECT count(*) FROM care_area != 0) , skipping'; fi"
        ])
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.evaka_service.name
          "awslogs-region"        = "${var.aws_region}"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    },
    {
      name      = "evaka-service"
      image     = data.aws_ssm_parameter.evaka_service_image.insecure_value
      essential = true

      dependsOn = [
        {
          containerName = "db-wait"
          condition     = "SUCCESS"
        }
      ]

      mountPoints = [
        {
          sourceVolume  = "shared-config"
          containerPath = "/config"
          readOnly      = false
        }
      ]

      linuxParameters = {
        initProcessEnabled = true
      }

      environment = concat(
        [
          {
            "name" : "DEPLOYMENT_BUCKET",
            "value" : aws_s3_bucket.evaka["deployment"].id
          },
          {
            "name" : "EVAKA_BUCKET_DECISIONS",
            "value" : aws_s3_bucket.evaka["decisions"].id
          },
          {
            "name" : "EVAKA_BUCKET_FEE_DECISIONS",
            "value" : aws_s3_bucket.evaka["fee-decisions"].id
          },
          {
            "name" : "EVAKA_BUCKET_INVOICES",
            "value" : aws_s3_bucket.evaka["invoices"].id
          },
          {
            "name" : "EVAKA_BUCKET_DATA",
            "value" : aws_s3_bucket.evaka["data"].id
          },
          {
            "name" : "EVAKA_BUCKET_ATTACHMENTS",
            "value" : aws_s3_bucket.evaka["attachments"].id
          },
          {
            "name" : "EVAKA_BUCKET_VOUCHER_VALUE_DECISIONS",
            "value" : aws_s3_bucket.evaka["voucher-value-decisions"].id
          },
          {
            "name" : "EVAKA_DATABASE_URL",
            "value" : "jdbc:postgresql://${var.rds_database_endpoint_address}:${var.rds_database_endpoint_port}/${var.evaka_db_name}?connectTimeout=60"
          },
          {
            "name" : "EVAKA_DATABASE_USERNAME",
            "value" : "evaka_application"
          },
          {
            "name" : "EVAKA_DATABASE_FLYWAY_USERNAME",
            "value" : "evaka_migration"
          },
        ],
        [
          for name, value in var.evaka_service_envvars : {
            "name" : name,
            "value" : value

        }]
      )

      secrets = concat(
        [
          {
            name      = "EVAKA_DATABASE_PASSWORD"
            valueFrom = var.evaka_db_application_user_password_arn
          },
          {
            name      = "EVAKA_DATABASE_FLYWAY_PASSWORD"
            valueFrom = var.evaka_db_migration_user_password_arn
          }
        ],
        [
          for name, valueFrom in var.evaka_service_secrets : {
            "name" : name,
            "valueFrom" : valueFrom
          }
        ]
      )

      portMappings = [
        {
          name          = "evaka-service"
          containerPort = 8888
          hostPort      = 8888
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]

      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl --silent --fail --show-error http://localhost:8888/health"
        ]
        interval    = 5
        retries     = 3
        timeout     = 5
        startPeriod = 180
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.evaka_service.name
          "awslogs-region"        = "${var.aws_region}"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    },
    {
      name      = "vtj-loader"
      image     = "curlimages/curl:8.12.1"
      essential = false

      mountPoints = [
        {
          sourceVolume  = "shared-config"
          containerPath = "/config"
          readOnly      = true
        }
      ]

      command = [
        "sh", "-c",
        "curl -X POST http://localhost:8888/dev-api/vtj-persons -H 'Content-Type: application/json' -d @/config/dev-data/mock-vtj-dataset.json && echo 'VTJ mock data loaded'"
      ]

      dependsOn = [
        {
          containerName = "dev-data-loader"
          condition     = "SUCCESS"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.evaka_service.name
          "awslogs-region"        = "${var.aws_region}"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "evaka_service" {
  name                   = "evaka-service"
  cluster                = aws_ecs_cluster.evaka.id
  task_definition        = aws_ecs_task_definition.evaka_service.arn
  desired_count          = local.evaka_service_desired_count
  launch_type            = "FARGATE"
  enable_execute_command = true
  wait_for_steady_state  = true

  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0

  deployment_circuit_breaker {
    enable   = true
    rollback = false
  }

  network_configuration {
    subnets          = [var.private_subnet_ids[0]]
    security_groups  = [aws_security_group.evaka_service.id]
    assign_public_ip = false
  }

  service_connect_configuration {
    enabled = true
    service {
      port_name = "evaka-service"
      client_alias {
        dns_name = "evaka-service"
        port     = 8888
      }
    }
  }

  depends_on = [
    aws_s3_object.evaka_service_jwks,
    aws_s3_object.evaka_service_trust_store,
    aws_s3_object.dev_data,
  ]
}
