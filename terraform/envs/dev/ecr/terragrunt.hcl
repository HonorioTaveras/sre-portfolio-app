# -----------------------------------------------------------------------------
# Dev ECR -- Environment Configuration
# No dependencies on other modules -- ECR is account-level, not VPC-level
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/ecr"
}

inputs = {
  env      = "dev"
  services = ["sre-portfolio-api", "sre-portfolio-worker"]
}
