# -----------------------------------------------------------------------------
# Dev EKS -- Environment Configuration
# Depends on VPC for subnet IDs and vpc_id
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/eks"
}

# Pull VPC outputs -- we need vpc_id and private_subnet_ids
dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  env                = "dev"
  vpc_id             = dependency.vpc.outputs.vpc_id
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids
  cluster_version    = "1.29"
  node_instance_type = "t3.small"  # 2 vCPU, 2GB -- enough for dev
  node_group_desired = 1           # single node saves ~$0.04/hr
  node_group_min     = 1
  node_group_max     = 2
}
