# -----------------------------------------------------------------------------
# RDS Module -- Input Variables
# -----------------------------------------------------------------------------

variable "env" {
  description = "Environment name (e.g. dev, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where RDS will be placed"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block -- used to allow inbound Postgres from within the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the RDS subnet group"
  type        = list(string)
}

variable "instance_class" {
  description = "RDS instance type"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Name of the initial database to create"
  type        = string
  default     = "sre_portfolio"
}

variable "db_username" {
  description = "Master username for the database"
  type        = string
  default     = "sre_admin"
}

variable "db_password" {
  description = "Master password for the database -- passed in from environment config"
  type        = string
  sensitive   = true
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarm notifications"
  type        = string
}
