variable "name" {
  description = "Service + task family name, e.g. oidc-demo-app-staging."
  type        = string
}

variable "app_env" {
  description = "Value for the APP_ENV env var (staging or production)."
  type        = string
}

variable "cluster_id" {
  description = "ECS cluster id/ARN this service runs in."
  type        = string
}

variable "region" {
  description = "AWS region (for the awslogs driver)."
  type        = string
}

variable "app_port" {
  description = "Container port."
  type        = number
}

variable "desired_count" {
  description = "Number of tasks to run."
  type        = number
  default     = 1
}

variable "vpc_id" {
  description = "VPC id (for the task security group)."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets to place tasks in."
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "ALB security group id; the task SG only allows inbound from this."
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group ARN the service registers into."
  type        = string
}

variable "bootstrap_image" {
  description = "Placeholder image for the first apply (replaced by the pipeline)."
  type        = string
}

variable "cpu" {
  description = "Fargate task CPU units."
  type        = string
  default     = "256"
}

variable "memory" {
  description = "Fargate task memory (MiB)."
  type        = string
  default     = "512"
}

variable "log_retention_days" {
  description = "CloudWatch log retention."
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags to apply."
  type        = map(string)
  default     = {}
}
