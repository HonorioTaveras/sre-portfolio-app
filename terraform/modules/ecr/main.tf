# -----------------------------------------------------------------------------
# ECR Module
# Creates Elastic Container Registry repositories for storing Docker images.
# One repo per service -- the CI pipeline pushes images here and EKS pulls
# from here when deploying pods.
# -----------------------------------------------------------------------------

resource "aws_ecr_repository" "repos" {
  # Create one repo for each service name passed in via var.services
  for_each = toset(var.services)

  name                 = "${var.env}-${each.value}"
  image_tag_mutability = "MUTABLE"

  # Scan images for vulnerabilities on every push
  # Results are visible in the AWS console under ECR > your repo > Scan results
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.env}-${each.value}"
  }
}

# -----------------------------------------------------------------------------
# Lifecycle policy -- keeps the last 10 images and deletes older ones
# Prevents the registry from filling up with stale images over time
# -----------------------------------------------------------------------------
resource "aws_ecr_lifecycle_policy" "repos" {
  for_each   = aws_ecr_repository.repos
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images, expire older ones"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}
