# -----------------------------------------------------------------------------
# VPC Module -- Input Variables
# These are the values the module expects to receive when it is called.
# Defining them here makes the module reusable across dev, staging, and prod.
# -----------------------------------------------------------------------------

variable "env" {
  description = "Environment name -- used for tagging and naming resources (e.g. dev, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC (e.g. 10.0.0.0/16)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones to create subnets in"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}
