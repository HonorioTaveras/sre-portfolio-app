# -----------------------------------------------------------------------------
# Dev VPC -- Environment Configuration
# This file tells Terragrunt which module to use and what inputs to pass in.
# Terragrunt reads the root terragrunt.hcl via find_in_parent_folders()
# which automatically configures the S3 backend and AWS provider.
# -----------------------------------------------------------------------------

# Pull in the root terragrunt.hcl for backend and provider config
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Point to the reusable VPC module
terraform {
  source = "../../../modules/vpc"
}

# Dev-specific values passed into the module variables
inputs = {
  env                = "dev"
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]
}
