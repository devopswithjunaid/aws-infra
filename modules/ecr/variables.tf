variable "repository_name" {
  description = "Name of the ECR repository."
  type        = string
}

variable "keep_last_images" {
  description = "How many recent images to retain (lifecycle policy)."
  type        = number
  default     = 10
}

variable "tags" {
  description = "Tags to apply."
  type        = map(string)
  default     = {}
}
