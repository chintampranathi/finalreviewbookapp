# ============================================
# Module: CloudWatch Monitoring
# Alarms for EC2, ALB, RDS
# SNS alerts to email
# ============================================

terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

variable "env" {}
variable "region" {}
variable "asg_name" {}
variable "alb_arn_suffix" {}
variable "tg_arn_suffix" {}
variable "rds_identifier" {}
variable "alert_email" {}

# SNS Topic — sends alert emails
resource "aws_sns_topic" "alerts" {
  name = "bookreview-${var.env}-${var.region}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ============================================
# EC2 / ASG ALARMS
# ============================================

# Alert when CPU goes above 80%
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "bookreview-${var.env}-${var.region}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU above 80% — consider scaling"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = var.asg_name
  }
}

# Alert when CPU drops below 20% (over-provisioned)
resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "bookreview-${var.env}-${var.region}-low-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 20
  alarm_description   = "CPU below 20% — scale down possible"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = var.asg_name
  }
}

# ============================================
# ALB ALARMS
# ============================================

# Alert when response time exceeds 2 seconds
resource "aws_cloudwatch_metric_alarm" "high_latency" {
  alarm_name          = "bookreview-${var.env}-${var.region}-high-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 2
  alarm_description   = "Response time above 2 seconds — performance issue"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.tg_arn_suffix
  }
}

# Alert when 5XX errors exceed 10 per minute
resource "aws_cloudwatch_metric_alarm" "high_5xx" {
  alarm_name          = "bookreview-${var.env}-${var.region}-high-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"
  alarm_description   = "High 5XX errors — app issues detected"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
}

# Alert when healthy host count drops below 1
resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "bookreview-${var.env}-${var.region}-unhealthy-hosts"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "No healthy hosts — CRITICAL"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.tg_arn_suffix
  }
}

# ============================================
# RDS ALARMS
# ============================================

# Alert when DB CPU exceeds 75%
resource "aws_cloudwatch_metric_alarm" "db_high_cpu" {
  alarm_name          = "bookreview-${var.env}-${var.region}-db-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 120
  statistic           = "Average"
  threshold           = 75
  alarm_description   = "RDS CPU above 75%"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = var.rds_identifier
  }
}

# Alert when free storage drops below 5GB
resource "aws_cloudwatch_metric_alarm" "db_low_storage" {
  alarm_name          = "bookreview-${var.env}-${var.region}-db-low-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Minimum"
  threshold           = 5368709120 # 5GB in bytes
  alarm_description   = "RDS free storage below 5GB — add storage soon"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = var.rds_identifier
  }
}

# ============================================
# CLOUDWATCH DASHBOARD
# ============================================

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "bookreview-${var.env}-${var.region}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          title  = "EC2 CPU Utilization"
          metrics = [["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", var.asg_name]]
          period = 60
          stat   = "Average"
          region = var.region
        }
      },
      {
        type = "metric"
        properties = {
          title  = "ALB Response Time"
          metrics = [["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix]]
          period = 60
          stat   = "Average"
          region = var.region
        }
      },
      {
        type = "metric"
        properties = {
          title  = "ALB 5XX Errors"
          metrics = [["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix]]
          period = 60
          stat   = "Sum"
          region = var.region
        }
      },
      {
        type = "metric"
        properties = {
          title  = "RDS CPU"
          metrics = [["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_identifier]]
          period = 60
          stat   = "Average"
          region = var.region
        }
      }
    ]
  })
}
