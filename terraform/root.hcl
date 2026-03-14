# -----------------------------------------------------------------------------
# Root Terragrunt configuration (root.hcl pattern)
# All environment-specific terragrunt.hcl files inherit from this using
# find_in_parent_folders(). Defines remote state and the AWS provider once
# so you never repeat it per module.
# -----------------------------------------------------------------------------

# Remote state -- stores Terraform state in S3.
# use_lockfile = true is the modern replacement for dynamodb_table locking.
# Terragrunt will auto-create the S3 bucket when you run with --backend-bootstrap.
remote_state {
  backend = "s3"

  config = {
    # Bucket name includes account ID to ensure global uniqueness
    bucket = "sre-portfolio-tfstate-${get_aws_account_id()}"

    # Each module gets its own state file path based on its folder location
    # e.g. envs/dev/vpc/terraform.tfstate
    key = "${path_relative_to_include()}/terraform.tfstate"

    region = "us-east-1"

    # Encrypt state at rest -- always enable this
    encrypt = true

    # Modern locking approach -- no DynamoDB table required
    use_lockfile = true
  }

  # Terragrunt auto-creates the S3 bucket if it doesn't exist
  # when you pass --backend-bootstrap
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# -----------------------------------------------------------------------------
# Generate the AWS provider for every module automatically.
# Without this you'd need a provider.tf in every single module folder.
# -----------------------------------------------------------------------------
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<EOF
provider "aws" {
  region  = "us-east-1"
  profile = "sre-portfolio"

  # These tags are applied to every resource Terraform creates.
  # Makes it easy to find all project resources in the AWS console.
  default_tags {
    tags = {
      project    = "sre-portfolio"
      managed-by = "terraform"
    }
  }
}
EOF
}
