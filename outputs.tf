# outputs.tf (root)
# -----------------
# Printed after apply and visible in the pipeline log. Copy these into the
# sample-app repo as GitHub Actions VARIABLES so its deploy workflow knows which
# roles/cluster/services/registry to use.

output "aws_region" {
  value       = var.region
  description = "Region everything is deployed in."
}

output "ecr_repository_url" {
  value       = module.ecr.repository_url
  description = "ECR repo URL to docker push/pull."
}

output "ecs_cluster_name" {
  value       = aws_ecs_cluster.main.name
  description = "ECS cluster name."
}

output "staging_service_name" {
  value       = module.staging_service.service_name
  description = "Staging ECS service name."
}

output "production_service_name" {
  value       = module.production_service.service_name
  description = "Production ECS service name."
}

output "staging_task_family" {
  value       = module.staging_service.task_family
  description = "Staging task definition family."
}

output "production_task_family" {
  value       = module.production_service.task_family
  description = "Production task definition family."
}

output "staging_deploy_role_arn" {
  value       = module.staging_deploy_role.role_arn
  description = "Role the STAGING GitHub job assumes via OIDC."
}

output "production_deploy_role_arn" {
  value       = module.production_deploy_role.role_arn
  description = "Role the PRODUCTION GitHub job assumes via OIDC."
}

output "oidc_provider_arn" {
  value       = module.github_oidc.provider_arn
  description = "ARN of the GitHub OIDC identity provider."
}
