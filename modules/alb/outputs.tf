output "dns_name" {
  description = "Public DNS name of the ALB (curl this to reach the app)."
  value       = aws_lb.this.dns_name
}

output "target_group_arn" {
  description = "Target group ARN the ECS service registers into."
  value       = aws_lb_target_group.this.arn
}

output "security_group_id" {
  description = "ALB security group id (tasks allow inbound only from this)."
  value       = aws_security_group.alb.id
}

output "listener_arn" {
  description = "Listener ARN (used to order service creation after the ALB is ready)."
  value       = aws_lb_listener.this.arn
}
