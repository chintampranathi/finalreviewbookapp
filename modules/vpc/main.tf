# ============================================
# Module: VPC
# Creates VPC, subnets, IGW, NAT Gateway,
# route tables for one region
# ============================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "env" {}
variable "region" {}
variable "vpc_cidr" {}
variable "public_subnets" {}
variable "private_subnets" {}
variable "db_subnets" {}
variable "azs" {}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "bookreview-${var.env}-${var.region}-vpc"
    Env  = var.env
  }
}

# Internet Gateway — allows public subnets to reach internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "bookreview-${var.env}-${var.region}-igw"
  }
}

# Public Subnets — Web tier (accessible from internet)
resource "aws_subnet" "public" {
  count             = length(var.public_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnets[count.index]
  availability_zone = var.azs[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name = "bookreview-${var.env}-public-${count.index + 1}"
    Tier = "web"
  }
}

# Private Subnets — App tier (Node.js EC2, not internet facing)
resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name = "bookreview-${var.env}-private-${count.index + 1}"
    Tier = "app"
  }
}

# DB Subnets — Database tier (RDS MariaDB, most restricted)
resource "aws_subnet" "db" {
  count             = length(var.db_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.db_subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name = "bookreview-${var.env}-db-${count.index + 1}"
    Tier = "database"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "bookreview-${var.env}-nat-eip"
  }
}

# NAT Gateway — allows private subnets to reach internet (for updates/patches)
# Sits in public subnet but serves private subnet traffic
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "bookreview-${var.env}-${var.region}-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

# Public Route Table — routes internet traffic via IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "bookreview-${var.env}-public-rt"
  }
}

# Private Route Table — routes internet traffic via NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "bookreview-${var.env}-private-rt"
  }
}

# DB Route Table — no internet access at all
resource "aws_route_table" "db" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "bookreview-${var.env}-db-rt"
  }
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Associate private subnets with private route table
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Associate db subnets with db route table
resource "aws_route_table_association" "db" {
  count          = length(aws_subnet.db)
  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.db.id
}

# Outputs used by other modules
output "vpc_id"              { value = aws_vpc.main.id }
output "public_subnet_ids"  { value = aws_subnet.public[*].id }
output "private_subnet_ids" { value = aws_subnet.private[*].id }
output "db_subnet_ids"      { value = aws_subnet.db[*].id }
