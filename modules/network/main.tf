# modules/network
# ===============
# We reuse the account's DEFAULT VPC and subnets (they already route to the
# internet), so there is no VPC/NAT/ALB cost. This module just discovers them
# and creates one security group (a virtual firewall) for the app tasks.

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "app" {
  name        = "${var.name_prefix}-app-sg"
  description = "Allow inbound on app port; all outbound (ECR pull, CloudWatch logs)."
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "App port"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-app-sg" })
}
