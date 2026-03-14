# -----------------------------------------------------------------------------
# ECR Module -- Outputs
# Repository URLs are needed by the CI pipeline to know where to push images
# and by EKS to know where to pull them from
# -----------------------------------------------------------------------------

output "repository_urls" {
  description = "Map of service name to ECR repository URL"
  value       = { for k, v in aws_ecr_repository.repos : k => v.repository_url }
}
