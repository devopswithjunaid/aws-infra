# modules/ecs-service
# ===================
# Everything needed to RUN one environment's container on Fargate:
#   - a task execution role (AWS pulls the image + writes logs with this)
#   - a task role (the app's own runtime identity; empty by default)
#   - a CloudWatch log group
#   - a task definition (bootstrap image; the pipeline replaces it later)
#   - the ECS service (keeps desired_count tasks running)
#
# Instantiated twice by the root module: once for staging, once for production.

# ---- Task roles (shared trust: only ECS tasks may assume) ----
data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task_execution" {
  name               = "${var.name}-task-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name               = "${var.name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
  tags               = var.tags
  # No policies: the demo app calls no AWS services (least privilege).
}

# ---- Logs ----
resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# ---- Task definition (bootstrap) ----
resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name         = "app" # stable name; the deploy pipeline references it
      image        = var.bootstrap_image
      essential    = true
      portMappings = [{ containerPort = var.app_port, protocol = "tcp" }]
      environment = [
        { name = "APP_ENV", value = var.app_env },
        { name = "IMAGE_TAG", value = "bootstrap" }, # pipeline overrides with git SHA
        { name = "PORT", value = tostring(var.app_port) }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "app"
        }
      }
    }
  ])

  tags = var.tags
}

# ---- Service ----
resource "aws_ecs_service" "this" {
  name            = var.name
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.security_group_id]
    assign_public_ip = true # public IP so we can curl it without an ALB
  }

  lifecycle {
    # The deploy pipeline owns the running image + scale; Terraform must not revert.
    ignore_changes = [task_definition, desired_count]
  }

  tags = var.tags
}
