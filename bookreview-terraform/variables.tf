# ============================================
# Variables — Book Review App
# ============================================

variable "env" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "instance_type" {
  description = "EC2 instance type for app tier"
  type        = string
  default     = "t3.micro"
}

variable "asg_min_size" {
  description = "Minimum number of EC2 instances in ASG"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximum number of EC2 instances in ASG"
  type        = number
  default     = 6
}

variable "asg_desired_capacity" {
  description = "Desired number of EC2 instances in ASG"
  type        = number
  default     = 2
}

variable "db_name" {
  description = "MariaDB database name"
  type        = string
  default     = "bookreviewdb"
}

variable "db_username" {
  description = "MariaDB master username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "MariaDB master password"
  type        = string
  sensitive   = true
}

variable "alert_email" {
  description = "Email address for CloudWatch alerts"
  type        = string
}
