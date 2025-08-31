terraform {
  source = "../../../modules/eso-irsa"
}

inputs = {
  namespace            = "external-secrets"
  service_account_name = "external-secrets"
  oidc_provider_arn    = "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/oidc.eks.<region>.amazonaws.com/id/<OIDC_ID>"
}
