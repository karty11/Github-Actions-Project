variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "namespace" {
  description = "Namespace where external-secrets is deployed"
  type        = string
  default     = "external-secrets"
}

variable "service_account_name" {
  description = "Service account name for external-secrets operator"
  type        = string
  default     = "external-secrets"
}
