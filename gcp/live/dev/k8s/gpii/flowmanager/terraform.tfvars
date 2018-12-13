# ↓ Module metadata
terragrunt = {
  terraform {
    source = "/project/modules//gpii-flowmanager"
  }

  dependencies {
    paths = [
      "../../kube-system/cert-manager",
      "../nginx-ingress",
      "../couchdb",
    ]
  }

  include = {
    path = "${find_in_parent_folders()}"
  }
}

# ↓ Module configuration (empty means all default)

cert_issuer_name     = "letsencrypt-staging"
disable_ssl_redirect = "true"

requests_cpu      = "250m"
requests_memory   = "256Mi"
limits_cpu        = "500m"
limits_memory     = "256Mi"
