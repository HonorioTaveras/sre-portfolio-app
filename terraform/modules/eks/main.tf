# -----------------------------------------------------------------------------
# EKS Module
# Creates a managed Kubernetes cluster on AWS. EKS has two layers:
# 1. Control plane -- managed by AWS, you never touch these servers
# 2. Node group -- EC2 instances that run your actual pods
# Both live in your VPC private subnets.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# IAM Role for the EKS Control Plane
# EKS needs permission to make AWS API calls on your behalf --
# for example, creating load balancers or modifying security groups
# -----------------------------------------------------------------------------
resource "aws_iam_role" "eks_cluster" {
  name = "${var.env}-sre-portfolio-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.env}-sre-portfolio-eks-cluster-role"
  }
}

# Attach AWS managed policies required for EKS control plane operation
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# -----------------------------------------------------------------------------
# IAM Role for EKS Worker Nodes
# EC2 instances in the node group need permissions to:
# - Pull images from ECR
# - Register with the EKS cluster
# - Send logs and metrics to CloudWatch
# -----------------------------------------------------------------------------
resource "aws_iam_role" "eks_nodes" {
  name = "${var.env}-sre-portfolio-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.env}-sre-portfolio-eks-node-role"
  }
}

# These three policies are the minimum required for EKS worker nodes
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_ecr_readonly" {
  # Allows nodes to pull images from any ECR repo in your account
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

# -----------------------------------------------------------------------------
# Security Group for EKS Control Plane
# Controls traffic between the control plane and worker nodes
# -----------------------------------------------------------------------------
resource "aws_security_group" "eks_cluster" {
  name        = "${var.env}-sre-portfolio-eks-cluster-sg"
  description = "EKS cluster control plane security group"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.env}-sre-portfolio-eks-cluster-sg"
  }
}

# -----------------------------------------------------------------------------
# EKS Cluster -- the Kubernetes control plane
# AWS manages the API server, etcd, and scheduler
# You only manage what runs on the nodes
# -----------------------------------------------------------------------------
resource "aws_eks_cluster" "main" {
  name     = "${var.env}-sre-portfolio"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [aws_security_group.eks_cluster.id]
    # endpoint_private_access allows nodes to reach the API server privately
    endpoint_private_access = true
    # endpoint_public_access allows kubectl from your laptop
    endpoint_public_access  = true
  }

  # Ensure IAM roles are created before the cluster
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]

  tags = {
    Name = "${var.env}-sre-portfolio"
  }
}

# -----------------------------------------------------------------------------
# EKS Node Group -- the EC2 instances that run your pods
# Managed node groups handle node provisioning, updates, and termination
# -----------------------------------------------------------------------------
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.env}-sre-portfolio-nodes"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = var.private_subnet_ids

  # t3.medium gives 2 vCPU and 4GB RAM -- enough for dev workloads
  instance_types = [var.node_instance_type]

  scaling_config {
    desired_size = var.node_group_desired
    min_size     = var.node_group_min
    max_size     = var.node_group_max
  }

  # Rolling update strategy -- replaces nodes one at a time
  update_config {
    max_unavailable = 1
  }

  # Ensure IAM policies are attached before creating nodes
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_readonly,
  ]

  tags = {
    Name = "${var.env}-sre-portfolio-nodes"
  }
}

# -----------------------------------------------------------------------------
# OIDC Provider -- enables IRSA (IAM Roles for Service Accounts)
# IRSA lets individual Kubernetes pods assume IAM roles without needing
# static credentials. Your API pod gets SQS access, your worker pod gets
# SQS access -- each with their own scoped IAM role.
# This is the secure, modern way to give pods AWS permissions.
# -----------------------------------------------------------------------------
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = {
    Name = "${var.env}-sre-portfolio-oidc"
  }
}
