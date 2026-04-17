
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "default" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
  url             = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_role" "github_actions_role_infra" {
  name               = join("-", [var.name_prefix, "github-actions-role-infra"])
  description        = "IAM Role for ${var.evaka_infra_repository_name} GitHub Actions (GitHub OIDC IdP)"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy_document_infra.json
}

resource "aws_iam_role_policy_attachment" "github_actions_infra" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  role       = aws_iam_role.github_actions_role_infra.name
}

data "aws_iam_policy_document" "assume_role_policy_document_infra" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.evaka_infra_repository_name}:environment:dev"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.default.arn]
    }
  }
}

resource "aws_iam_role" "github_actions_role_app" {
  name               = join("-", [var.name_prefix, "github-actions-role-app"])
  description        = "IAM Role for ${var.evaka_app_repository_name} GitHub Actions (GitHub OIDC IdP)"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy_document_app.json
}

data "aws_iam_policy_document" "github_actions_app_ecr" {
  # ECR login token — must be resource "*"
  statement {
    sid       = "ECRGetAuthorizationToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Push/pull permissions scoped to the four application repositories
  statement {
    sid    = "ECRPushPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [
      "arn:aws:ecr:${var.aws_region}:${var.aws_account_id}:repository/dummy-idp",
      "arn:aws:ecr:${var.aws_region}:${var.aws_account_id}:repository/evaka/api-gateway",
      "arn:aws:ecr:${var.aws_region}:${var.aws_account_id}:repository/evaka/frontend-common",
      "arn:aws:ecr:${var.aws_region}:${var.aws_account_id}:repository/evaka/service",
    ]
  }
}

resource "aws_iam_policy" "github_actions_app_ecr" {
  name        = join("-", [var.name_prefix, "github-actions-app-ecr"])
  description = "Allows ${var.evaka_app_repository_name} GitHub Actions to push images to ECR"
  policy      = data.aws_iam_policy_document.github_actions_app_ecr.json
}

resource "aws_iam_role_policy_attachment" "github_actions_app" {
  policy_arn = aws_iam_policy.github_actions_app_ecr.arn
  role       = aws_iam_role.github_actions_role_app.name
}

data "aws_iam_policy_document" "assume_role_policy_document_app" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.evaka_app_repository_name}:environment:dev"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.default.arn]
    }
  }
}
