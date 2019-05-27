# ↓ Module metadata
terragrunt = {
  terraform {
    source = "/project/modules//gcp-stackdriver-lbm-prd"
  }

  include = {
    path = "${find_in_parent_folders()}"
  }
}

# ↓ Module configuration (empty means all default)
