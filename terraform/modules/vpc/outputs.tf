# -----------------------------------------------------------------------------
# VPC Module -- Outputs
# These values are exposed so other modules can reference them.
# For example, the EKS module needs to know the VPC ID and subnet IDs
# to know where to place the cluster.
# -----------------------------------------------------------------------------

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs -- used for load balancers"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs -- used for EKS nodes and RDS"
  value       = aws_subnet.private[*].id
}
