terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
  }
}

# ---------- Data sources ----------
data "aws_eks_cluster" "eks" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "eks_auth" {
  name = var.cluster_name
}


# ---------- Providers ----------
provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks_auth.token
}

# ---------- OIDC provider ----------
locals {
  oidc_url = try(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "")
}
resource "aws_iam_openid_connect_provider" "eks" {
  url            = local.oidc_url
  client_id_list = ["sts.amazonaws.com"]

  # Default thumbprint for AWS OIDC root CA
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
}

resource "aws_iam_role" "external_secrets" {
  name = "external-secrets-iam-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
            "${replace(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}


# Attach Secrets Manager policy
resource "aws_iam_role_policy_attachment" "external_secrets" {
  role       = aws_iam_role.external_secrets.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

# Namespace for External Secrets
resource "kubernetes_namespace" "external_secrets" {
  metadata {
    name = var.namespace
  }

  lifecycle {
    prevent_destroy = true
  }
}

# ServiceAccount annotated with IRSA role
resource "kubernetes_service_account" "external_secrets" {
  metadata {
    name      = var.service_account_name
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.external_secrets.arn
    }
  }
}

resource "null_resource" "check_cluster" {
  provisioner "local-exec" {
    command = "echo 'External Secrets IRSA deployed for cluster ${var.cluster_name}, namespace ${var.namespace}'"
  }
}
