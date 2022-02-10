module "cp4d-instance" {
  source = "./module"

  depends_on = [
    module.gitops_cp4d_operator,
    module.gitops_cp_foundation
  ]

  gitops_config = module.gitops.gitops_config
  git_credentials = module.gitops.git_credentials
  server_name = module.gitops.server_name
  namespace = module.gitops_namespace.name
  kubeseal_cert = module.gitops.sealed_secrets_cert
}
