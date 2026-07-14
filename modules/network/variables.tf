variable "name_prefix" {
  description = "Prefix for naming VPC resources."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "tags" {
  description = "Tags to apply."
  type        = map(string)
  default     = {}
}
