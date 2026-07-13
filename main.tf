# main.tf (root module)
# =====================
# This is the "wiring diagram". It creates the few shared/singleton resources
# (ECS cluster) and calls the reusable child modules under ./modules. The two
# environments are produced by instantiating the SAME modules twice with
# different inputs -- staging vs production differ only by those inputs.

data "aws_caller_identity" "current" {}

locals {
  # Common tags applied everywhere (provider default_tags also adds some).
  tags = {
    Project = var.project_name
  }

  account_id = data.aws_caller_identity.current.account_id
}

# ---- Shared singletons ----
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled" # keep demo cost at zero
  }

  tags = local.tags
}

module "github_oidc" {
  source       = "./modules/github-oidc"
  project_name = var.project_name
  tags         = local.tags
}

module "ecr" {
  source          = "./modules/ecr"
  repository_name = "${var.project_name}-app"
  tags            = local.tags
}

module "network" {
  source              = "./modules/network"
  name_prefix         = var.project_name
  app_port            = var.app_port
  allowed_cidr_blocks = var.allowed_cidr_blocks
  tags                = local.tags
}

# ---- STAGING environment ----
module "staging_service" {
  source            = "./modules/ecs-service"
  name              = "${var.project_name}-app-staging"
  app_env           = "staging"
  cluster_id        = aws_ecs_cluster.main.id
  region            = var.region
  app_port          = var.app_port
  desired_count     = var.desired_count
  subnet_ids        = module.network.subnet_ids
  security_group_id = module.network.security_group_id
  bootstrap_image   = var.bootstrap_image
  tags              = local.tags
}

module "staging_deploy_role" {
  source                  = "./modules/deploy-role"
  name                    = "${var.project_name}-staging-deploy"
  oidc_provider_arn       = module.github_oidc.provider_arn
  github_owner            = var.github_owner
  app_repo_name           = var.app_repo_name
  github_environment      = "staging"
  can_push_ecr            = true # staging BUILDS and PUSHES the image
  region                  = var.region
  account_id              = local.account_id
  cluster_name            = aws_ecs_cluster.main.name
  service_name            = module.staging_service.service_name
  ecr_repository_arn      = module.ecr.repository_arn
  task_execution_role_arn = module.staging_service.task_execution_role_arn
  task_role_arn           = module.staging_service.task_role_arn
  tags                    = local.tags
}

# ---- PRODUCTION environment ----
module "production_service" {
  source            = "./modules/ecs-service"
  name              = "${var.project_name}-app-production"
  app_env           = "production"
  cluster_id        = aws_ecs_cluster.main.id
  region            = var.region
  app_port          = var.app_port
  desired_count     = var.desired_count
  subnet_ids        = module.network.subnet_ids
  security_group_id = module.network.security_group_id
  bootstrap_image   = var.bootstrap_image
  tags              = local.tags
}

module "production_deploy_role" {
  source                  = "./modules/deploy-role"
  name                    = "${var.project_name}-production-deploy"
  oidc_provider_arn       = module.github_oidc.provider_arn
  github_owner            = var.github_owner
  app_repo_name           = var.app_repo_name
  github_environment      = "production"
  can_push_ecr            = false # production CANNOT push; it only promotes the staged image
  region                  = var.region
  account_id              = local.account_id
  cluster_name            = aws_ecs_cluster.main.name
  service_name            = module.production_service.service_name
  ecr_repository_arn      = module.ecr.repository_arn
  task_execution_role_arn = module.production_service.task_execution_role_arn
  task_role_arn           = module.production_service.task_role_arn
  tags                    = local.tags
}
