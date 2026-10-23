variable "aws_region" {
  description = "AWS region for the infrastructure"
  type        = string
  default     = "us-east-2"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}
variable "db_password" {
  description = "Password for the PostgreSQL database"
  type        = string
  sensitive   = true
}
