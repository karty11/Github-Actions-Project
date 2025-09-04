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

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

locals {
  oidc_url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url            = local.oidc_url
  client_id_list = ["sts.amazonaws.com"]

  # Default thumbprint for AWS OIDC root CA
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
}

# IAM role for External Secrets
resource "aws_iam_role" "external_secrets" {
  name = "eks-external-secrets-role"

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
            (format("%s:sub", replace(local.oidc_url, "https://", ""))) = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
            (format("%s:aud", replace(local.oidc_url, "https://", ""))) = "sts.amazonaws.com"
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
