variable "name_prefix" {
  description = "Prefix for naming the security group."
  type        = string
}

variable "app_port" {
  description = "TCP port the container listens on."
  type        = number
}

variable "allowed_cidr_blocks" {
  description = "CIDR ranges allowed to reach the app port."
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply."
  type        = map(string)
  default     = {}
}
