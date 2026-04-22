# ============================================
# Module: Auto Scaling Group
# Launches EC2 instances running Node.js
# in private subnets, registers with ALB
# ============================================

terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

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

# Get latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# IAM Role for EC2 — allows CloudWatch access
resource "aws_iam_role" "ec2_role" {
  name = "bookreview-${var.env}-${var.region}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "bookreview-${var.env}-${var.region}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# Launch Template — defines how each EC2 is launched
resource "aws_launch_template" "app" {
  name_prefix   = "bookreview-${var.env}-${var.region}-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.app_sg_id]
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  # User data — runs on EC2 startup
  # Installs Node.js, clones app, starts it
  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e

    # Update system
    yum update -y

    # Install Node.js 18
    curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
    yum install -y nodejs git

    # Install PM2 — keeps Node.js running
    npm install -g pm2

    # Install CloudWatch agent
    yum install -y amazon-cloudwatch-agent

    # Clone book review app
    cd /home/ec2-user
    git clone https://github.com/yourusername/bookreview-app.git app
    cd app

    # Set environment variables
    cat > .env << 'ENVFILE'
    NODE_ENV=production
    PORT=3000
    DB_HOST=${var.db_endpoint}
    DB_NAME=${var.db_name}
    DB_USER=${var.db_username}
    DB_PASS=${var.db_password}
    ENVFILE

    # Install dependencies
    npm install --production

    # Start app with PM2
    pm2 start app.js --name bookreview
    pm2 startup
    pm2 save

    # Start CloudWatch agent
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config -m ec2 -s

    echo "Book Review App started successfully!"
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

# Auto Scaling Group — manages EC2 instances
resource "aws_autoscaling_group" "app" {
  name                = "bookreview-${var.env}-${var.region}-asg"
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [var.target_group_arn]
  health_check_type   = "ELB"
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

# Scale UP policy — add instances when CPU > 70%
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "bookreview-${var.env}-scale-up"
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

# Scale DOWN policy — remove instances when CPU < 30%
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "bookreview-${var.env}-scale-down"
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

output "asg_name"          { value = aws_autoscaling_group.app.name }
output "scale_up_arn"      { value = aws_autoscaling_policy.scale_up.arn }
output "scale_down_arn"    { value = aws_autoscaling_policy.scale_down.arn }
