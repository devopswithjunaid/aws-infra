output "vpc_id" {
  description = "Default VPC id."
  value       = data.aws_vpc.default.id
}

output "subnet_ids" {
  description = "Default subnet ids (tasks are spread across these)."
  value       = data.aws_subnets.default.ids
}

output "security_group_id" {
  description = "Security group id for the app tasks."
  value       = aws_security_group.app.id
}
