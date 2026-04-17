# Current nginx doesn't support using hosts-file.
# eVaka API-GW registers itself with internal dns so frontend's nginx can find it.
resource "aws_service_discovery_private_dns_namespace" "evaka" {
  name        = "evaka.local"
  description = "DNS based Service Registry namespace for eVaka internal connections"
  vpc         = var.vpc_id
}

# Rest of the services uses hosts-file for name resolution and can find other services with it
resource "aws_service_discovery_http_namespace" "evaka" {
  name        = lower(var.name_prefix)
  description = "hosts-file based Service Connect namespace for eVaka internal connections"
}

# Create ECS Cluster
resource "aws_ecs_cluster" "evaka" {
  name = lower(var.name_prefix)
  service_connect_defaults {
    namespace = aws_service_discovery_http_namespace.evaka.arn
  }
}


# Common IAM Policies

# Common Assume Role Policy for ECS Task and Task Execution Roles
data "aws_iam_policy_document" "assume_ecs_task_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:ecs:${var.aws_region}:${var.aws_account_id}:*"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.aws_account_id]
    }
  }
}

# Common IAM Policy to Allow ECS Exec
resource "aws_iam_policy" "allow_ecs_exec" {
  name        = join("-", [lower(var.name_prefix), "allow-ecs-exec"])
  path        = "/"
  description = "Allow ECS Exec"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ],
        "Resource" : "*"
      }
    ]
  })
}
