# -----------------------------------------------------------------------------
# Root Terragrunt configuration
# Every environment-specific terragrunt.hcl inherits from this file using
# find_in_parent_folders(). This means you define remote state and the AWS
# provider once here instead of repeating it in every module.
# -----------------------------------------------------------------------------

# Remote state configuration -- stores Terraform state in S3 with DynamoDB
# locking so multiple people can't run apply at the same time and corrupt state.
remote_state {
  backend = "s3"

  config = {
    # Bucket name is unique per AWS account to avoid naming collisions
    bucket = "sre-portfolio-tfstate-${get_aws_account_id()}"

    # Each module gets its own state file based on its folder path
    # e.g. envs/dev/vpc/terraform.tfstate
    key = "${path_relative_to_include()}/terraform.tfstate"

    region = "us-east-1"

    # Encrypt state at rest -- always do this
    encrypt = true

    # DynamoDB table for state locking -- prevents concurrent applies
    dynamodb_table = "sre-portfolio-tfstate-lock"
  }

  # Terragrunt will create the S3 bucket and DynamoDB table automatically
  # if they don't exist yet
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# -----------------------------------------------------------------------------
# Generate the AWS provider configuration for every module automatically.
# Without this, you'd have to copy a provider.tf into every module folder.
# -----------------------------------------------------------------------------
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<EOF
provider "aws" {
  region  = "us-east-1"
  profile = "sre-portfolio"

  # These tags get applied to every resource created by Terraform.
  # Makes it easy to find and filter resources in the AWS console.
  default_tags {
    tags = {
      project    = "sre-portfolio"
      managed-by = "terraform"
    }
  }
}
EOF
}
