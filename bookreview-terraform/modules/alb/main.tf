# ============================================
# Module: Application Load Balancer
# Distributes traffic across EC2 instances
# in the app tier across multiple AZs
# ============================================

terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

variable "env" {}
variable "region" {}
variable "vpc_id" {}
variable "public_subnet_ids" {}
variable "alb_sg_id" {}

# Application Load Balancer — sits in public subnets
resource "aws_lb" "main" {
  name               = "bookreview-${var.env}-${var.region}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name   = "bookreview-${var.env}-${var.region}-alb"
    Env    = var.env
    Region = var.region
  }
}

# Target Group — where ALB sends traffic (our Node.js EC2s)
resource "aws_lb_target_group" "app" {
  name     = "bookreview-${var.env}-${var.region}-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  tags = { Name = "bookreview-${var.env}-${var.region}-tg" }
}

# Listener — ALB listens on port 80, forwards to target group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

output "alb_dns_name"   { value = aws_lb.main.dns_name }
output "alb_arn_suffix" { value = aws_lb.main.arn_suffix }
output "tg_arn_suffix"  { value = aws_lb_target_group.app.arn_suffix }
output "target_group_arn" { value = aws_lb_target_group.app.arn }
