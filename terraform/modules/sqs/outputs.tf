# -----------------------------------------------------------------------------
# SQS Module -- Outputs
# The queue URL is needed by the worker and API services at runtime
# to send and receive messages
# -----------------------------------------------------------------------------

output "queue_url" {
  description = "URL of the main SQS queue -- passed to services as an environment variable"
  value       = aws_sqs_queue.main.url
}

output "queue_arn" {
  description = "ARN of the main SQS queue -- used for IAM policy permissions"
  value       = aws_sqs_queue.main.arn
}

output "dlq_url" {
  description = "URL of the dead-letter queue -- for monitoring failed messages"
  value       = aws_sqs_queue.dlq.url
}

output "sns_topic_arn" {
  description = "ARN of the alerts SNS topic -- used for CloudWatch alarm actions"
  value       = aws_sns_topic.alerts.arn
}
