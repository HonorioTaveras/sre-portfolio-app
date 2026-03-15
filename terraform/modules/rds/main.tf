# -----------------------------------------------------------------------------
# RDS Module
# Creates a Postgres database in the private subnets of the VPC.
# RDS is never directly reachable from the internet -- only resources inside
# the VPC (like your EKS pods) can connect to it.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Subnet group -- tells RDS which subnets it can place the database in.
# We use private subnets so the DB is never exposed to the internet.
# -----------------------------------------------------------------------------
resource "aws_db_subnet_group" "main" {
  name       = "${var.env}-sre-portfolio-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.env}-sre-portfolio-db-subnet-group"
  }
}

# -----------------------------------------------------------------------------
# Security group -- controls which resources can connect to the database.
# Only allows inbound Postgres traffic (port 5432) from within the VPC.
# Everything else is blocked by default.
# -----------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name        = "${var.env}-sre-portfolio-rds-sg"
  description = "Allow Postgres access from within the VPC only"
  vpc_id      = var.vpc_id

  ingress {
    description = "Postgres from within VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.env}-sre-portfolio-rds-sg"
  }
}

# -----------------------------------------------------------------------------
# RDS Postgres instance
# db.t3.micro is the smallest instance type -- cheap for dev/learning.
# Multi-AZ is disabled for cost -- enable it for production.
# -----------------------------------------------------------------------------
resource "aws_db_instance" "main" {
  identifier        = "${var.env}-sre-portfolio-db"
  engine            = "postgres"
  engine_version    = "15"
  instance_class    = var.instance_class
  allocated_storage = 20
  storage_type      = "gp2"

  # Database credentials -- in production these come from Secrets Manager
  # For dev we use variables, but we'll pull from Secrets Manager in the app
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Place the DB in our private subnet group
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Skip final snapshot on destroy -- saves time when tearing down dev environments
  # In production set this to true and specify a snapshot identifier
  skip_final_snapshot = true

  # Disable multi-AZ for dev -- reduces cost significantly
  multi_az = false

  # Allow minor version upgrades automatically
  auto_minor_version_upgrade = true

  tags = {
    Name = "${var.env}-sre-portfolio-db"
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Alarm -- fires when RDS CPU exceeds 80% for 4 minutes
# High CPU on RDS usually means slow queries or too many connections
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${var.env}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU above 80% for 4 minutes"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }
}

# -----------------------------------------------------------------------------
# Store the DB password in AWS Secrets Manager
# The application retrieves it at runtime via IAM role -- never hardcoded
# -----------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.env}/sre-portfolio/db-password"
  description             = "RDS Postgres password for sre-portfolio ${var.env}"
  recovery_window_in_days = 0 # Allow immediate deletion in dev

  tags = {
    Name = "${var.env}-sre-portfolio-db-password"
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = aws_db_instance.main.address
    port     = 5432
    dbname   = var.db_name
  })
}
