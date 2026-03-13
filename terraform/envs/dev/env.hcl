# -----------------------------------------------------------------------------
# Dev Environment -- shared variables
# Referenced by the root terragrunt.hcl and available to all modules
# in this environment via read_terragrunt_config()
# -----------------------------------------------------------------------------

locals {
  env_name = "dev"
  region   = "us-east-1"
}
