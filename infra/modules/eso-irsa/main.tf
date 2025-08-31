variable "namespace" {
  default = "external-secrets"
}

variable "service_account_name" {
  default = "external-secrets"
}

variable "oidc_provider_arn" {
  type = string
}

data "aws_caller_identity" "current" {}

resource "aws_iam_policy" "eso_policy" {
  name        = "ESOSecretsAccess"
  description = "Allows ESO to fetch secrets from AWS Secrets Manager & SSM"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "*"
      }
    ]
  })
}

data "aws_iam_policy_document" "eso_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_arn, "arn:aws:iam::", "")}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
  }
}

resource "aws_iam_role" "eso_irsa" {
  name               = "external-secrets-irsa"
  assume_role_policy = data.aws_iam_policy_document.eso_assume.json
}

resource "aws_iam_role_policy_attachment" "eso_policy_attach" {
  role       = aws_iam_role.eso_irsa.name
  policy_arn = aws_iam_policy.eso_policy.arn
}

output "eso_irsa_role_arn" {
  value = aws_iam_role.eso_irsa.arn
}
