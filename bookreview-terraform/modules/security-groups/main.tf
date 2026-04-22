# ============================================
# Module: Security Groups
# ALB SG — open to internet (80, 443)
# App SG — only from ALB
# DB SG  — only from App tier
# ============================================

terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

variable "env" {}
variable "vpc_id" {}

# ALB Security Group — internet facing
resource "aws_security_group" "alb" {
  name        = "bookreview-${var.env}-alb-sg"
  description = "Allow HTTP and HTTPS from internet to ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "bookreview-${var.env}-alb-sg" }
}

# App Security Group — only accepts traffic from ALB
resource "aws_security_group" "app" {
  name        = "bookreview-${var.env}-app-sg"
  description = "Allow traffic only from ALB to Node.js app"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Node.js app port from ALB only"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "bookreview-${var.env}-app-sg" }
}

# DB Security Group — only accepts traffic from App tier
resource "aws_security_group" "db" {
  name        = "bookreview-${var.env}-db-sg"
  description = "Allow MariaDB traffic only from App tier"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MariaDB port from App tier only"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "bookreview-${var.env}-db-sg" }
}

output "alb_sg_id" { value = aws_security_group.alb.id }
output "app_sg_id" { value = aws_security_group.app.id }
output "db_sg_id"  { value = aws_security_group.db.id }
