# modules/deploy-role
# ===================
# One IAM role that a GitHub Actions job assumes via OIDC to deploy ONE
# environment. Instantiated twice by the root module.
#
# The two documents below are the entire security story:
#   TRUST      -> who can assume it (exact repo + GitHub environment)
#   PERMISSION -> what they can do   (least privilege, scoped by ARN)
#
# The only behavioural difference between staging and production is the input
# var.github_environment (changes the trusted `sub`) and var.can_push_ecr
# (whether the ECR push statement is included). Everything else is identical,
# which is exactly what makes the staging/production comparison legible.

# ---------------- TRUST POLICY ----------------
data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    # Token audience must be sts.amazonaws.com.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Token subject must EXACTLY match this repo + this GitHub environment.
    # StringEquals (not StringLike) => no wildcards, no other repo/branch/env.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_owner}/${var.app_repo_name}:environment:${var.github_environment}"]
    }
  }
}

resource "aws_iam_role" "deploy" {
  name                 = var.name
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = 3600
  tags                 = merge(var.tags, { Name = var.name })
}

# ---------------- PERMISSION POLICY ----------------
data "aws_iam_policy_document" "permissions" {

  # ECR login token: AWS requires Resource "*" for this specific action.
  statement {
    sid       = "EcrAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # ECR read (pull/inspect), scoped to our repo. Both roles get this.
  statement {
    sid    = "EcrRead"
    effect = "Allow"
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchCheckLayerAvailability",
    ]
    resources = [var.ecr_repository_arn]
  }

  # ECR push, scoped to our repo. ONLY included when can_push_ecr = true
  # (staging). Its ABSENCE on production is denied-scenario groundwork:
  # production physically cannot push new image bytes.
  dynamic "statement" {
    for_each = var.can_push_ecr ? [1] : []
    content {
      sid    = "EcrPush"
      effect = "Allow"
      actions = [
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
      ]
      resources = [var.ecr_repository_arn]
    }
  }

  # Register/describe task definitions. AWS does not support resource-level
  # scoping for these actions, so Resource must be "*" (documented API limit).
  statement {
    sid       = "EcsTaskDef"
    effect    = "Allow"
    actions   = ["ecs:RegisterTaskDefinition", "ecs:DescribeTaskDefinition"]
    resources = ["*"]
  }

  # Update ONLY this environment's service. This ARN scope is the enforcement
  # boundary for denied-scenario #4 (staging creds cannot touch prod service).
  statement {
    sid       = "EcsServiceUpdate"
    effect    = "Allow"
    actions   = ["ecs:UpdateService", "ecs:DescribeServices"]
    resources = ["arn:aws:ecs:${var.region}:${var.account_id}:service/${var.cluster_name}/${var.service_name}"]
  }

  # PassRole: scoped to THIS environment's task roles only, and only when handed
  # to the ECS tasks service.
  statement {
    sid       = "PassTaskRoles"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [var.task_execution_role_arn, var.task_role_arn]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "permissions" {
  name   = "${var.name}-permissions"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.permissions.json
}
