# -----------------------------------------------------------------------------
# RDS Module -- Outputs
# The endpoint and secret ARN are needed by the application at runtime
# -----------------------------------------------------------------------------

output "db_endpoint" {
  description = "RDS instance endpoint -- host:port format"
  value       = aws_db_instance.main.endpoint
}

output "db_address" {
  description = "RDS instance hostname only (no port)"
  value       = aws_db_instance.main.address
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.main.db_name
}

output "db_secret_arn" {
  description = "ARN of the Secrets Manager secret containing DB credentials"
  value       = aws_secretsmanager_secret.db_password.arn
}

output "db_security_group_id" {
  description = "Security group ID for the RDS instance"
  value       = aws_security_group.rds.id
}
