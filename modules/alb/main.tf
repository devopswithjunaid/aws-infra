# modules/alb
# ===========
# One internet-facing Application Load Balancer for a single environment.
# It sits in the PUBLIC subnets and forwards traffic to the Fargate tasks that
# run in the PRIVATE subnets (registered by IP in the target group).
#
# Created per environment (staging, production) so each has its own DNS name
# and can be secured/scaled independently.

# Security group for the ALB: allow inbound HTTP from the internet.
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "Allow inbound HTTP to the ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from allowed CIDRs"
    from_port   = var.listener_port
    to_port     = var.listener_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    description = "All outbound (to reach tasks)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-alb-sg" })
}

# The load balancer itself, spread across the public subnets.
resource "aws_lb" "this" {
  name               = var.name
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids
  tags               = merge(var.tags, { Name = var.name })
}

# Target group: where the Fargate tasks register (by IP, because awsvpc mode).
# The health check hits the app's /health endpoint on the container port.
resource "aws_lb_target_group" "this" {
  name        = var.name
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = var.health_check_path
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = merge(var.tags, { Name = var.name })
}

# Listener: accept HTTP on the listener port and forward to the target group.
resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.listener_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
