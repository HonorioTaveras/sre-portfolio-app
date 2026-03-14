# -----------------------------------------------------------------------------
# SQS Module
# Creates a main queue for job processing and a dead-letter queue (DLQ).
# The DLQ catches messages that fail processing repeatedly -- instead of
# losing them, they land in the DLQ where you can inspect and reprocess them.
# This is a standard production pattern for async job processing.
# -----------------------------------------------------------------------------

# Dead-letter queue -- receives messages that fail after max_receive_count attempts
resource "aws_sqs_queue" "dlq" {
  name = "${var.env}-sre-portfolio-dlq"

  # Keep failed messages for 14 days so you have time to investigate
  message_retention_seconds = 1209600

  tags = {
    Name = "${var.env}-sre-portfolio-dlq"
  }
}

# Main queue -- the worker service polls this for jobs to process
resource "aws_sqs_queue" "main" {
  name = "${var.env}-sre-portfolio-jobs"

  # How long a message is hidden from other consumers after being received
  # Give the worker 5 minutes to process before the message becomes visible again
  visibility_timeout_seconds = 300

  # Keep unprocessed messages for 4 days
  message_retention_seconds = 345600

  # Redrive policy -- after 3 failed processing attempts, move to DLQ
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name = "${var.env}-sre-portfolio-jobs"
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Alarm -- fires when messages sit unprocessed for over 5 minutes
# This means the worker is either down or stuck.
# The alarm fires to an SNS topic which you can wire to email or PagerDuty.
# -----------------------------------------------------------------------------
resource "aws_sns_topic" "alerts" {
  name = "${var.env}-sre-portfolio-alerts"

  tags = {
    Name = "${var.env}-sre-portfolio-alerts"
  }
}

resource "aws_cloudwatch_metric_alarm" "sqs_message_age" {
  alarm_name          = "${var.env}-sqs-message-age-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Maximum"

  # Alert if messages are sitting unprocessed for more than 5 minutes
  threshold         = 300
  alarm_description = "SQS messages unprocessed for over 5 minutes -- worker may be down"
  alarm_actions     = [aws_sns_topic.alerts.arn]

  dimensions = {
    QueueName = aws_sqs_queue.main.name
  }
}
