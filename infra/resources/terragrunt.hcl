terraform {
  source = "../modules/external-secrets-irsa"
}

inputs = {
  cluster_name          = "project-cluster"
  namespace             = "external-secrets"
  service_account_name  = "external-secrets"
}