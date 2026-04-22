# ============================================
# Outputs — Book Review App
# ============================================

output "alb_dns_mumbai" {
  description = "ALB DNS for Mumbai region"
  value       = module.alb_mumbai.alb_dns_name
}

output "alb_dns_hyderabad" {
  description = "ALB DNS for Hyderabad region"
  value       = module.alb_hyderabad.alb_dns_name
}

output "rds_endpoint_mumbai" {
  description = "RDS primary endpoint (Mumbai)"
  value       = module.rds_mumbai.db_endpoint
  sensitive   = true
}

output "rds_endpoint_hyderabad" {
  description = "RDS read replica endpoint (Hyderabad)"
  value       = module.rds_hyderabad.db_endpoint
  sensitive   = true
}
