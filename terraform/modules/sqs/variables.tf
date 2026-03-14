# -----------------------------------------------------------------------------
# SQS Module -- Input Variables
# -----------------------------------------------------------------------------

variable "env" {
  description = "Environment name used for naming queues (e.g. dev, prod)"
  type        = string
}
