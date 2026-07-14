variable "name" {
  description = "Name for the ALB and its resources, e.g. oidc-demo-staging."
  type        = string
}

variable "vpc_id" {
  description = "VPC to create the ALB and target group in."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets the ALB spans (at least 2 AZs)."
  type        = list(string)
}

variable "app_port" {
  description = "Container port the target group forwards to."
  type        = number
}

variable "listener_port" {
  description = "Port the ALB listens on for inbound traffic."
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "Path the target group health check requests."
  type        = string
  default     = "/health"
}

variable "allowed_cidr_blocks" {
  description = "CIDRs allowed to reach the ALB."
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply."
  type        = map(string)
  default     = {}
}
