output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.web.dns_name
}

output "rds_endpoint" {
  description = "Endpoint of the PostgreSQL database"
  value       = aws_db_instance.postgres.address
}

output "vpc_id" {
  description = "ID of the Terraform-managed VPC"
  value       = aws_vpc.main.id
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.web.name
}
