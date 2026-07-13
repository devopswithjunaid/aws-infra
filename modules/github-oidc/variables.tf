variable "project_name" {
  description = "Prefix used for naming/tagging."
  type        = string
}

variable "tags" {
  description = "Tags to apply to created resources."
  type        = map(string)
  default     = {}
}
