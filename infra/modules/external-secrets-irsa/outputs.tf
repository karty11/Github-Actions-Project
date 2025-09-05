output "external_secrets_irsa_role_arn" {
  description = "IAM Role ARN for External Secrets Operator"
  value       = aws_iam_role.external_secrets_irsa.arn
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for EKS"
  value       = aws_iam_openid_connect_provider.eks.arn
}
