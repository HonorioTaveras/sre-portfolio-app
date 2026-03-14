# -----------------------------------------------------------------------------
# Dev SQS -- Environment Configuration
# No VPC dependency -- SQS is a managed AWS service, not VPC-bound
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/sqs"
}

inputs = {
  env = "dev"
}
