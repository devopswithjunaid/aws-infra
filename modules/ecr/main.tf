# modules/ecr
# ===========
# Private Docker registry for the app image. One repo is shared by both
# environments: staging pushes the image, production pulls the SAME image.

resource "aws_ecr_repository" "this" {
  name                 = var.repository_name
  image_tag_mutability = "IMMUTABLE" # a pushed tag (git SHA) can never be overwritten
  force_delete         = true        # allow `terraform destroy` to remove non-empty repo (demo only)

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, { Name = var.repository_name })
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.keep_last_images} images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.keep_last_images
        }
        action = { type = "expire" }
      }
    ]
  })
}
