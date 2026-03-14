# -----------------------------------------------------------------------------
# Makefile -- local dev shortcuts
# Run 'make <target>' from the repo root
# -----------------------------------------------------------------------------

# Print all current Terraform outputs across every provisioned module
.PHONY: outputs
outputs:
	@echo "=== VPC ===" && (cd terraform/envs/dev/vpc && terragrunt output)
	@echo "=== ECR ===" && (cd terraform/envs/dev/ecr && terragrunt output)
	@echo "=== SQS ===" && (cd terraform/envs/dev/sqs && terragrunt output)

# Destroy all dev infrastructure in reverse dependency order
.PHONY: destroy-dev
destroy-dev:
	@echo "Destroying EKS..." && (cd terraform/envs/dev/eks && terragrunt destroy)
	@echo "Destroying RDS..." && (cd terraform/envs/dev/rds && terragrunt destroy)
	@echo "Destroying SQS..." && (cd terraform/envs/dev/sqs && terragrunt destroy)
	@echo "Destroying ECR..." && (cd terraform/envs/dev/ecr && terragrunt destroy)
	@echo "Destroying VPC..." && (cd terraform/envs/dev/vpc && terragrunt destroy)
