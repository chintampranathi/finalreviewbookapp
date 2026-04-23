# Book Review App — 3-Tier AWS Architecture

A production-ready 3-tier architecture deployed across 2 AWS regions using Terraform and GitHub Actions CI/CD.

## Architecture

```
                        INTERNET
                           │
              ┌────────────┴────────────┐
              │                         │
         ap-south-1                ap-south-2
          (Mumbai)                (Hyderabad)
              │                         │
         ┌────▼────┐               ┌────▼────┐
         │   ALB   │               │   ALB   │
         └────┬────┘               └────┬────┘
    PUBLIC SUBNET                PUBLIC SUBNET
              │                         │
         ┌────▼────┐               ┌────▼────┐
         │  ASG    │               │  ASG    │
         │ Node.js │               │ Node.js │
         │  EC2s   │               │  EC2s   │
         └────┬────┘               └────┬────┘
   PRIVATE SUBNET               PRIVATE SUBNET
              │                         │
         ┌────▼────┐               ┌────▼────┐
         │   RDS   │──replication──│   RDS   │
         │ MariaDB │               │ Replica │
         │ Primary │               │         │
         └─────────┘               └─────────┘
      DB SUBNET                  DB SUBNET
```

## What's Inside

- **VPC** — Custom VPC with public, private, and DB subnets across 2 AZs per region
- **ALB** — Application Load Balancer distributing traffic across EC2 instances
- **ASG** — Auto Scaling Group scaling Node.js EC2s based on CPU (min 2, max 6)
- **RDS MariaDB** — Primary in Mumbai with read replica in Hyderabad
- **CloudWatch** — Alarms for CPU, latency, 5XX errors, unhealthy hosts, DB storage
- **CI/CD** — GitHub Actions pipeline: validate → plan → apply on merge to main
- **Remote State** — Terraform state stored in S3 with DynamoDB locking

## Security

- ALB in public subnets — accepts internet traffic on 80/443
- EC2 instances in private subnets — only accessible from ALB
- RDS in DB subnets — only accessible from EC2 app tier
- Security groups enforce least-privilege between tiers
- All DB passwords stored as GitHub Secrets — never in code

## How to Deploy

### Prerequisites
- AWS account with appropriate IAM permissions
- Terraform >= 1.5.0 installed
- AWS CLI configured

### Steps

```bash
# 1. Clone the repo
git clone https://github.com/yourusername/bookreview-terraform.git
cd bookreview-terraform

# 2. Create S3 bucket for remote state (one time only)
aws s3 mb s3://bookreview-terraform-state --region ap-south-1

# 3. Create DynamoDB table for state locking (one time only)
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-south-1

# 4. Copy and fill variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# 5. Initialise Terraform
terraform init

# 6. Plan — see what will be created
terraform plan

# 7. Apply — deploy the infrastructure
terraform apply
```

### CI/CD Setup (GitHub Actions)

Add these secrets to your GitHub repository:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `DB_USERNAME`
- `DB_PASSWORD`
- `ALERT_EMAIL`

Once secrets are added — every push to `main` automatically deploys infrastructure.

## CloudWatch Monitoring

Alarms configured for:
- EC2 CPU > 80% → SNS email alert
- EC2 CPU < 20% → scale down suggestion
- ALB response time > 2 seconds → performance alert
- ALB 5XX errors > 10/min → app error alert
- ALB healthy hosts < 1 → critical alert
- RDS CPU > 75% → DB performance alert
- RDS storage < 5GB → storage alert

## Tech Stack

| Layer | Technology |
|---|---|
| Infrastructure as Code | Terraform |
| Cloud Provider | AWS |
| Regions | ap-south-1 (Mumbai) + ap-south-2 (Hyderabad) |
| Compute | EC2 + Auto Scaling Group |
| Load Balancer | Application Load Balancer |
| App Runtime | Node.js 18 on Amazon Linux 2 |
| Database | RDS MariaDB 10.11 (Multi-AZ + Read Replica) |
| Monitoring | CloudWatch Alarms + Dashboard |
| CI/CD | GitHub Actions |
| State Management | S3 + DynamoDB |

## Authors

Your Name — [LinkedIn](https://linkedin.com/in/yourprofile) | [GitHub](https://github.com/yourusername)
test
