# -----------------------------------------------------------------------------
# ECR Module -- Input Variables
# -----------------------------------------------------------------------------

variable "env" {
  description = "Environment name used for naming repositories (e.g. dev, prod)"
  type        = string
}

variable "services" {
  description = "List of service names to create repositories for"
  type        = list(string)
  # Default creates repos for both services in this project
  default     = ["sre-portfolio-api", "sre-portfolio-worker"]
}
