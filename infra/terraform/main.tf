locals {
  name_prefix = var.project_name
  github_repo  = "${var.github_org}/${var.github_repo}"
}

resource "aws_ecr_repository" "exec_dev" {
  name                 = "${local.name_prefix}-exec-dev"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "exec_staging" {
  name                 = "${local.name_prefix}-exec-staging"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "exec_prod" {
  name                 = "${local.name_prefix}-exec-prod"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = var.github_oidc_thumbprints
}

data "aws_iam_policy_document" "github_actions_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.github_repo}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_actions_image" {
  name               = "${local.name_prefix}-gha-ecr-cosign"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume.json
}

data "aws_iam_policy_document" "github_actions_ecr_kms" {
  statement {
    sid    = "EcrAuth"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "EcrPush"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
      "ecr:ListImages",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
    resources = [
      aws_ecr_repository.exec_dev.arn,
      aws_ecr_repository.exec_staging.arn,
      aws_ecr_repository.exec_prod.arn,
    ]
  }

  statement {
    sid    = "CosignKms"
    effect = "Allow"
    actions = [
      "kms:DescribeKey",
      "kms:GetPublicKey",
      "kms:Sign",
      "kms:Verify",
    ]
    resources = [aws_kms_key.cosign.arn]
  }
}

resource "aws_iam_role_policy" "github_actions_image" {
  name   = "${local.name_prefix}-ecr-cosign"
  role   = aws_iam_role.github_actions_image.id
  policy = data.aws_iam_policy_document.github_actions_ecr_kms.json
}

data "aws_iam_policy_document" "kms_cosign" {
  statement {
    sid    = "AccountAdmin"
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
      ]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "GitHubActionsSign"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.github_actions_image.arn]
    }
    actions = [
      "kms:DescribeKey",
      "kms:GetPublicKey",
      "kms:Sign",
      "kms:Verify",
    ]
    resources = ["*"]
  }
}

resource "aws_kms_key" "cosign" {
  description              = "${local.name_prefix} Cosign container signing (ECC P-256)"
  customer_master_key_spec = "ECC_NIST_P256"
  key_usage                = "SIGN_VERIFY"
  deletion_window_in_days  = 7

  policy = data.aws_iam_policy_document.kms_cosign.json
}

resource "aws_kms_alias" "cosign" {
  name          = "alias/${local.name_prefix}-cosign-signing"
  target_key_id = aws_kms_key.cosign.key_id
}
