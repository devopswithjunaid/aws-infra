# main.tf (root module)
# =====================
# The "wiring diagram". Creates the shared singletons (VPC via the network
# module, ECS cluster) and instantiates the reusable child modules under
# ./modules. Staging and production are produced by calling the SAME modules
# twice with different inputs.
#
# Architecture:
#   network  -> VPC, public + private subnets, IGW, NAT, route tables
#   alb (x2) -> one internet-facing ALB per environment (in public subnets)
#   ecs      -> Fargate service per environment (in PRIVATE subnets, behind ALB)
#   deploy   -> one OIDC-assumable deploy role per environment

data "aws_caller_identity" "current" {}

locals {
  tags       = { Project = var.project_name }
  account_id = data.aws_caller_identity.current.account_id
}

# ---- Shared networking ----
module "network" {
  source      = "./modules/network"
  name_prefix = var.project_name
  vpc_cidr    = var.vpc_cidr
  tags        = local.tags
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

# =========================================================================
# STAGING environment
# =========================================================================
module "staging_alb" {
  source              = "./modules/alb"
  name                = "${var.project_name}-staging"
  vpc_id              = module.network.vpc_id
  public_subnet_ids   = module.network.public_subnet_ids
  app_port            = var.app_port
  allowed_cidr_blocks = var.allowed_cidr_blocks
  tags                = local.tags
}

module "staging_service" {
  source                = "./modules/ecs-service"
  name                  = "${var.project_name}-app-staging"
  app_env               = "staging"
  cluster_id            = aws_ecs_cluster.main.id
  region                = var.region
  app_port              = var.app_port
  desired_count         = var.desired_count
  vpc_id                = module.network.vpc_id
  private_subnet_ids    = module.network.private_subnet_ids
  alb_security_group_id = module.staging_alb.security_group_id
  target_group_arn      = module.staging_alb.target_group_arn
  bootstrap_image       = var.bootstrap_image
  tags                  = local.tags

  # Ensure the ALB + listener exist before the service registers targets.
  depends_on = [module.staging_alb]
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

# =========================================================================
# PRODUCTION environment
# =========================================================================
module "production_alb" {
  source              = "./modules/alb"
  name                = "${var.project_name}-production"
  vpc_id              = module.network.vpc_id
  public_subnet_ids   = module.network.public_subnet_ids
  app_port            = var.app_port
  allowed_cidr_blocks = var.allowed_cidr_blocks
  tags                = local.tags
}

module "production_service" {
  source                = "./modules/ecs-service"
  name                  = "${var.project_name}-app-production"
  app_env               = "production"
  cluster_id            = aws_ecs_cluster.main.id
  region                = var.region
  app_port              = var.app_port
  desired_count         = var.desired_count
  vpc_id                = module.network.vpc_id
  private_subnet_ids    = module.network.private_subnet_ids
  alb_security_group_id = module.production_alb.security_group_id
  target_group_arn      = module.production_alb.target_group_arn
  bootstrap_image       = var.bootstrap_image
  tags                  = local.tags

  depends_on = [module.production_alb]
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
