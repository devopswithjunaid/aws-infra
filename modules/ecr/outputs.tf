output "repository_url" {
  description = "URL to docker push/pull (registry/repo)."
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "ARN of the repository (used to scope IAM push permissions)."
  value       = aws_ecr_repository.this.arn
}

output "repository_name" {
  description = "Repository name."
  value       = aws_ecr_repository.this.name
}
