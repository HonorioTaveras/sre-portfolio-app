# -----------------------------------------------------------------------------
# EKS Module -- Input Variables
# -----------------------------------------------------------------------------

variable "env" {
  description = "Environment name (e.g. dev, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the EKS cluster will be placed"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the EKS node group and control plane"
  type        = list(string)
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.29"
}

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_group_desired" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_group_min" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_group_max" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}
