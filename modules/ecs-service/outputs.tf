output "service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.this.name
}

output "task_family" {
  description = "Task definition family."
  value       = aws_ecs_task_definition.this.family
}

output "task_execution_role_arn" {
  description = "Task execution role ARN (passed to the deploy role's PassRole)."
  value       = aws_iam_role.task_execution.arn
}

output "task_role_arn" {
  description = "Task role ARN (passed to the deploy role's PassRole)."
  value       = aws_iam_role.task.arn
}
