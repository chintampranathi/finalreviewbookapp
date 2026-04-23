# ============================================
# Module: RDS MariaDB
# Primary in Mumbai, Read Replica in Hyderabad
# Sits in most private DB subnet
# ============================================

terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

variable "env" {}
variable "region" {}
variable "db_subnet_ids" {}
variable "db_sg_id" {}
variable "db_name" {}
variable "db_username" {}
variable "db_password" {}
variable "is_primary" { type = bool }
variable "primary_db_arn" { default = "" }

# DB Subnet Group — tells RDS which subnets to use
resource "aws_db_subnet_group" "main" {
  name       = "bookreview-${var.env}-${var.region}-db-subnet"
  subnet_ids = var.db_subnet_ids

  tags = { Name = "bookreview-${var.env}-${var.region}-db-subnet" }
}

# Primary RDS instance (Mumbai)
resource "aws_db_instance" "primary" {
  count = var.is_primary ? 1 : 0

  identifier        = "bookreview-${var.env}-primary"
  engine            = "mariadb"
  engine_version    = "10.11"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp2"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.db_sg_id]

  # Multi-AZ for high availability within Mumbai region
  multi_az = true

  # Enable automated backups (required for read replicas)
  backup_retention_period = 1
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # Allow cross-region replication
  parameter_group_name = aws_db_parameter_group.mariadb.name

  skip_final_snapshot = false
  final_snapshot_identifier = "bookreview-final-snapshot"

  tags = {
    Name   = "bookreview-${var.env}-primary-db"
    Env    = var.env
    Region = "mumbai"
    Role   = "primary"
  }
}

# Read Replica (Hyderabad) — for disaster recovery
resource "aws_db_instance" "replica" {
  count = var.is_primary ? 0 : 1

  identifier          = "bookreview-${var.env}-replica"
  replicate_source_db = var.primary_db_arn
  instance_class      = "db.t3.micro"
  storage_encrypted   = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.db_sg_id]

  # No backups needed on replica
  backup_retention_period = 0
  skip_final_snapshot     = true

  tags = {
    Name   = "bookreview-${var.env}-replica-db"
    Env    = var.env
    Region = "hyderabad"
    Role   = "read-replica"
  }
}

# Parameter group — enables binary logging for replication
resource "aws_db_parameter_group" "mariadb" {
  name   = "bookreview-${var.env}-${var.region}-mariadb"
  family = "mariadb10.11"

  parameter {
    name  = "log_bin_trust_function_creators"
    value = "1"
  }

  tags = { Name = "bookreview-${var.env}-mariadb-params" }
}

output "db_endpoint" {
  value = var.is_primary ? aws_db_instance.primary[0].endpoint : aws_db_instance.replica[0].endpoint
}

output "db_identifier" {
  value = var.is_primary ? aws_db_instance.primary[0].identifier : aws_db_instance.replica[0].identifier
}

output "db_arn" {
  value = var.is_primary ? aws_db_instance.primary[0].arn : aws_db_instance.replica[0].arn
}
