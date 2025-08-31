output "external_secrets_role_arn" {
  description = "IAM role ARN assigned to the external-secrets service account"
  value       = aws_iam_role.external_secrets.arn
}

output "external_secrets_service_account" {
  description = "Name of the Kubernetes service account for external-secrets"
  value       = kubernetes_service_account.external_secrets.metadata[0].name
}
