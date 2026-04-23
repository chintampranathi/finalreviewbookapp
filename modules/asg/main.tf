# ============================================
# Module: Auto Scaling Group (FIXED VERSION)
# ============================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ================= VARIABLES =================
variable "env" {}
variable "region" {}
variable "private_subnet_ids" {}
variable "app_sg_id" {}
variable "target_group_arn" {}
variable "instance_type" {}
variable "min_size" {}
variable "max_size" {}
variable "desired_capacity" {}
variable "db_endpoint" {}
variable "db_name" {}
variable "db_username" {}
variable "db_password" {}

# ================= AMI =================
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# ================= LAUNCH TEMPLATE =================
resource "aws_launch_template" "app" {
  name_prefix   = "bookreview-${var.env}-${var.region}-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.app_sg_id]
  }

  # ❌ IAM REMOVED (to avoid conflicts)

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e

    yum update -y

    curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
    yum install -y nodejs git

    npm install -g pm2

    cd /home/ec2-user
    git clone https://github.com/yourusername/bookreview-app.git app
    cd app

    cat > .env << 'ENVFILE'
    NODE_ENV=production
    PORT=3000
    DB_HOST=${var.db_endpoint}
    DB_NAME=${var.db_name}
    DB_USER=${var.db_username}
    DB_PASS=${var.db_password}
    ENVFILE

    npm install --production

    pm2 start app.js --name bookreview
    pm2 startup
    pm2 save

    echo "App started"
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name   = "bookreview-${var.env}-${var.region}-app"
      Env    = var.env
      Region = var.region
      Tier   = "app"
    }
  }
}

# ================= ASG =================
resource "aws_autoscaling_group" "app" {
  name                = "bookreview-${var.env}-${var.region}-asg"
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [var.target_group_arn]

  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "bookreview-${var.env}-${var.region}-app"
    propagate_at_launch = true
  }
}

# ================= SCALING =================
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "bookreview-${var.env}-scale-up"
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "bookreview-${var.env}-scale-down"
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

# ================= OUTPUTS =================
output "asg_name" {
  value = aws_autoscaling_group.app.name
}

output "scale_up_arn" {
  value = aws_autoscaling_policy.scale_up.arn
}

output "scale_down_arn" {
  value = aws_autoscaling_policy.scale_down.arn
}
