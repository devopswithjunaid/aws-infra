variable "name" {
  description = "IAM role name, e.g. oidc-demo-staging-deploy."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider (from the github-oidc module)."
  type        = string
}

variable "github_owner" {
  description = "GitHub owner/org of the app repo."
  type        = string
}

variable "app_repo_name" {
  description = "App repo name whose workflows may assume this role."
  type        = string
}

variable "github_environment" {
  description = "GitHub environment this role is bound to (staging or production). Becomes part of the trusted sub claim."
  type        = string
}

variable "can_push_ecr" {
  description = "Whether this role may push image layers to ECR. true for staging, false for production."
  type        = bool
}

variable "region" {
  description = "AWS region (for building the service ARN)."
  type        = string
}

variable "account_id" {
  description = "AWS account id (for building the service ARN)."
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name (for building the service ARN)."
  type        = string
}

variable "service_name" {
  description = "The ECS service this role may update."
  type        = string
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repo (scopes read/push permissions)."
  type        = string
}

variable "task_execution_role_arn" {
  description = "Task execution role ARN this deploy role may PassRole."
  type        = string
}

variable "task_role_arn" {
  description = "Task role ARN this deploy role may PassRole."
  type        = string
}

variable "tags" {
  description = "Tags to apply."
  type        = map(string)
  default     = {}
}
