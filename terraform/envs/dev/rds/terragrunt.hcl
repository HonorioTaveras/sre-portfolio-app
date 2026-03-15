# -----------------------------------------------------------------------------
# Dev RDS -- Environment Configuration
# Depends on VPC (for subnet IDs) and SQS (for SNS topic ARN for alarms)
# Terragrunt reads outputs from those modules automatically via dependency blocks
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/rds"
}

# Pull VPC outputs -- we need vpc_id, vpc_cidr, and private_subnet_ids
dependency "vpc" {
  config_path = "../vpc"
}

# Pull SQS outputs -- we need the SNS topic ARN for CloudWatch alarms
dependency "sqs" {
  config_path = "../sqs"
}

inputs = {
  env                = "dev"
  vpc_id             = dependency.vpc.outputs.vpc_id
  vpc_cidr           = "10.0.0.0/16"
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids
  instance_class     = "db.t3.micro"
  db_name            = "sre_portfolio"
  db_username        = "sre_admin"

  # In a real production setup this would come from a secrets manager or
  # environment variable -- for dev a simple password is fine
  db_password   = "devpassword123!"
  sns_topic_arn = dependency.sqs.outputs.sns_topic_arn
}
