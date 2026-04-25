# ============================================
# Book Review App — 3-Tier Architecture
# Multi-Region: Mumbai + Hyderabad
# ============================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "bookreview-terraform-state"
    key            = "global/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

# ================= PROVIDERS =================

provider "aws" {
  alias  = "mumbai"
  region = "ap-south-1"
}

provider "aws" {
  alias  = "hyderabad"
  region = "ap-south-2"
}

# ============================================
# MUMBAI (PRIMARY)
# ============================================

module "vpc_mumbai" {
  source = "./modules/vpc"
  providers = { aws = aws.mumbai }

  env             = var.env
  region          = "mumbai"
  vpc_cidr        = "10.0.0.0/16"
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]
  db_subnets      = ["10.0.5.0/24", "10.0.6.0/24"]
  azs             = ["ap-south-1a", "ap-south-1b"]
}

module "security_groups_mumbai" {
  source = "./modules/security-groups"
  providers = { aws = aws.mumbai }

  env    = var.env
  vpc_id = module.vpc_mumbai.vpc_id
}

module "alb_mumbai" {
  source = "./modules/alb"
  providers = { aws = aws.mumbai }

  env               = var.env
  region            = "mumbai"
  vpc_id            = module.vpc_mumbai.vpc_id
  public_subnet_ids = module.vpc_mumbai.public_subnet_ids
  alb_sg_id         = module.security_groups_mumbai.alb_sg_id
}

module "rds_mumbai" {
  source = "./modules/rds"
  providers = { aws = aws.mumbai }

  env           = var.env
  region        = "primary"
  db_subnet_ids = module.vpc_mumbai.db_subnet_ids
  db_sg_id      = module.security_groups_mumbai.db_sg_id
  db_name       = var.db_name
  db_username   = var.db_username
  db_password   = var.db_password
  is_primary    = true
}

module "asg_mumbai" {
  source = "./modules/asg"
  providers = { aws = aws.mumbai }

  env                 = var.env
  region              = "mumbai"
  location            = "mumbai"   # ✅ REQUIRED
  private_subnet_ids  = module.vpc_mumbai.private_subnet_ids
  app_sg_id           = module.security_groups_mumbai.app_sg_id
  target_group_arn    = module.alb_mumbai.target_group_arn
  instance_type       = var.instance_type
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desired_capacity

  db_endpoint = module.rds_mumbai.db_endpoint
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password
}

module "cloudwatch_mumbai" {
  source = "./modules/cloudwatch"
  providers = { aws = aws.mumbai }

  env            = var.env
  region         = "mumbai"
  asg_name       = module.asg_mumbai.asg_name
  alb_arn_suffix = module.alb_mumbai.alb_arn_suffix
  tg_arn_suffix  = module.alb_mumbai.tg_arn_suffix
  rds_identifier = module.rds_mumbai.db_identifier
  alert_email    = var.alert_email
}

# ============================================
# HYDERABAD (SECONDARY)
# ============================================

module "vpc_hyderabad" {
  source = "./modules/vpc"
  providers = { aws = aws.hyderabad }

  env             = var.env
  region          = "hyderabad"
  vpc_cidr        = "10.1.0.0/16"
  public_subnets  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnets = ["10.1.3.0/24", "10.1.4.0/24"]
  db_subnets      = ["10.1.5.0/24", "10.1.6.0/24"]
  azs             = ["ap-south-2a", "ap-south-2b"]
}

module "security_groups_hyderabad" {
  source = "./modules/security-groups"
  providers = { aws = aws.hyderabad }

  env    = var.env
  vpc_id = module.vpc_hyderabad.vpc_id
}

module "alb_hyderabad" {
  source = "./modules/alb"
  providers = { aws = aws.hyderabad }

  env               = var.env
  region            = "hyderabad"
  vpc_id            = module.vpc_hyderabad.vpc_id
  public_subnet_ids = module.vpc_hyderabad.public_subnet_ids
  alb_sg_id         = module.security_groups_hyderabad.alb_sg_id
}

module "rds_hyderabad" {
  source = "./modules/rds"
  providers = { aws = aws.hyderabad }

  env            = var.env
  region         = "replica"
  db_subnet_ids  = module.vpc_hyderabad.db_subnet_ids
  db_sg_id       = module.security_groups_hyderabad.db_sg_id
  db_name        = var.db_name
  db_username    = var.db_username
  db_password    = var.db_password
  is_primary     = false
  primary_db_arn = module.rds_mumbai.db_arn
}

module "asg_hyderabad" {
  source = "./modules/asg"
  providers = { aws = aws.hyderabad }

  env                 = var.env
  region              = "hyderabad"
  location            = "hyderabad"   # ✅ REQUIRED
  private_subnet_ids  = module.vpc_hyderabad.private_subnet_ids
  app_sg_id           = module.security_groups_hyderabad.app_sg_id
  target_group_arn    = module.alb_hyderabad.target_group_arn
  instance_type       = var.instance_type
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desired_capacity

  db_endpoint = module.rds_hyderabad.db_endpoint
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password
}

module "cloudwatch_hyderabad" {
  source = "./modules/cloudwatch"
  providers = { aws = aws.hyderabad }

  env            = var.env
  region         = "hyderabad"
  asg_name       = module.asg_hyderabad.asg_name
  alb_arn_suffix = module.alb_hyderabad.alb_arn_suffix
  tg_arn_suffix  = module.alb_hyderabad.tg_arn_suffix
  rds_identifier = module.rds_hyderabad.db_identifier
  alert_email    = var.alert_email
}
