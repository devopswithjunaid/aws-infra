output "vpc_id" {
  description = "The VPC id."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public subnet ids (ALB + NAT live here)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet ids (Fargate tasks live here)."
  value       = aws_subnet.private[*].id
}
