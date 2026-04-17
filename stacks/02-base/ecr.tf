locals {
  ecr_lifecycle_policies = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than 14 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 14
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep 5 tagged images"
        selection = {
          tagStatus      = "tagged"
          tagPatternList = ["*"]
          countType      = "imageCountMoreThan"
          countNumber    = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}


resource "aws_ecr_repository" "dummy_idp" {
  name         = "dummy-idp"
  force_delete = true
}

resource "aws_ecr_repository" "evaka_frontend_common" {
  name         = "evaka/frontend-common"
  force_delete = true
}

resource "aws_ecr_repository" "evaka_apigw" {
  name         = "evaka/api-gateway"
  force_delete = true
}

resource "aws_ecr_repository" "evaka_service" {
  name         = "evaka/service"
  force_delete = true
}

resource "aws_ecr_lifecycle_policy" "dummy_idp" {
  repository = aws_ecr_repository.dummy_idp.name
  policy     = local.ecr_lifecycle_policies
}

resource "aws_ecr_lifecycle_policy" "evaka_frontend_common" {
  repository = aws_ecr_repository.evaka_frontend_common.name
  policy     = local.ecr_lifecycle_policies
}

resource "aws_ecr_lifecycle_policy" "evaka_apigw" {
  repository = aws_ecr_repository.evaka_apigw.name
  policy     = local.ecr_lifecycle_policies
}

resource "aws_ecr_lifecycle_policy" "evaka_service" {
  repository = aws_ecr_repository.evaka_service.name
  policy     = local.ecr_lifecycle_policies
}
