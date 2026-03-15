# -----------------------------------------------------------------------------
# EKS Module -- Outputs
# Used to configure kubectl and by other modules that need cluster details
# -----------------------------------------------------------------------------

output "cluster_name" {
  description = "EKS cluster name -- used with aws eks update-kubeconfig"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64 encoded cluster CA certificate"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN -- used for IRSA IAM role trust policies"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "OIDC provider URL -- used for IRSA IAM role trust policies"
  value       = aws_iam_openid_connect_provider.eks.url
}

output "node_role_arn" {
  description = "IAM role ARN for worker nodes"
  value       = aws_iam_role.eks_nodes.arn
}
