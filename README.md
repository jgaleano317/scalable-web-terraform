# Scalable AWS Web Application with Terraform

A highly available, horizontally scalable web application deployed on AWS and managed entirely through Terraform.

This project started as a hands-on AWS infrastructure build and was later rebuilt as Infrastructure as Code. The goal was to gain practical experience designing, deploying, troubleshooting, and managing a production-style cloud environment using core AWS services.

![AWS Scalable Web Application Architecture](architecture.png)

## What This Project Demonstrates

- AWS VPC and subnet architecture
- Multi-AZ infrastructure
- Public and private subnet separation
- Application Load Balancing
- EC2 Auto Scaling
- Launch Templates
- PostgreSQL on Amazon RDS
- AWS Secrets Manager
- IAM roles and least-privilege access
- Security groups and network-level access control
- Flask and Gunicorn
- Linux systemd services
- Infrastructure as Code with Terraform
- AWS CLI troubleshooting
- Health checks and automated instance replacement
- Git and GitHub workflow

## AWS Infrastructure

### Networking

The infrastructure is deployed in `us-east-2` using a dedicated VPC:

- VPC: `10.0.0.0/16`
- 2 public subnets across separate Availability Zones
- 2 private subnets across separate Availability Zones
- Internet Gateway for public traffic
- Public route table
- Private subnets used for the database

The EC2 instances are placed in public subnets because this project intentionally avoids a NAT Gateway to reduce unnecessary AWS costs. The application itself is protected by security groups and is accessed through the Application Load Balancer.

### Compute

EC2 instances run:

- Amazon Linux 2023
- `t3.micro`
- Python 3
- Flask
- Gunicorn
- systemd

The Auto Scaling Group is configured with:

- Minimum: 2 instances
- Desired: 2 instances
- Maximum: 4 instances
- CPU target tracking: 60%
- Elastic Load Balancing health checks

When an unhealthy instance is detected, the Auto Scaling Group can terminate and replace it automatically.

### Load Balancing

An internet-facing Application Load Balancer receives HTTP traffic on port 80 and forwards requests to the EC2 target group on port 8000.

The target group uses:

```text
Health Check Path: /health
Protocol: HTTP
Port: 8000
Expected Status: 200
```

The `/health` endpoint verifies that the application can successfully communicate with the PostgreSQL database.

### Database

The application uses Amazon RDS PostgreSQL:

- PostgreSQL 17
- `db.t3.micro`
- 20 GB gp3 storage
- Storage encryption enabled
- Single-AZ deployment
- Public access disabled
- Database located in private subnets

The database security group only permits PostgreSQL traffic from the EC2 security group.

### Secrets Management

Database credentials are stored in AWS Secrets Manager rather than being hard-coded into the application.

The EC2 instances use an IAM instance role that permits:

```text
secretsmanager:GetSecretValue
```

only for the application's database secret.

The Flask application retrieves the credentials at runtime using `boto3`.

## Application

The Flask application provides a simple server inventory interface.

The homepage retrieves server information from PostgreSQL and displays:

- Server ID
- Hostname
- Environment
- Status
- IP address

Example:

```text
Server Inventory

ID   Hostname        Environment   Status    IP Address
1    web-server-01   production    running   10.0.1.91
2    web-server-02   production    running   10.0.2.25
3    web-server-03   staging       stopped   10.0.2.26
```

The application also provides:

```text
/health
```

which performs a database connectivity check.

A successful response is:

```text
healthy - database connection successful
```

## Terraform Structure

The infrastructure is separated into logical Terraform files:

| File | Purpose |
|---|---|
| `provider.tf` | AWS provider and default configuration |
| `variables.tf` | Configurable Terraform variables |
| `networking.tf` | VPC, subnets, routes, and Internet Gateway |
| `security-groups.tf` | ALB, EC2, and RDS security groups |
| `database.tf` | RDS PostgreSQL and DB subnet group |
| `iam.tf` | IAM role, policy, instance profile, and Secrets Manager secret |
| `compute.tf` | EC2 Launch Template and application bootstrap |
| `load-balancer.tf` | Application Load Balancer and target group |
| `autoscaling.tf` | Auto Scaling Group and scaling policy |
| `outputs.tf` | Useful infrastructure outputs |

## Deployment

Initialize Terraform:

```bash
terraform init
```

Validate the configuration:

```bash
terraform validate
```

Review the planned changes:

```bash
terraform plan
```

Apply the infrastructure:

```bash
terraform apply
```

Terraform provisions the networking, security, database, IAM, compute, load balancing, and Auto Scaling components.

## Security Considerations

Several security controls were implemented as part of the project:

- RDS is not publicly accessible.
- Database traffic is restricted to the EC2 security group.
- EC2 application traffic is restricted to the Application Load Balancer.
- Database credentials are stored in Secrets Manager.
- EC2 uses an IAM role instead of long-lived AWS credentials.
- The Secrets Manager IAM policy is scoped to the application's specific secret.
- Temporary SSH access used during troubleshooting was removed after deployment.
- Terraform state files are excluded from Git using `.gitignore`.
- Terraform variable files are excluded from Git.
- AWS credentials and database passwords are not stored in the repository.

## Troubleshooting and Lessons Learned

One of the most valuable parts of this project was troubleshooting the EC2 bootstrap process.

The initial Launch Template versions experienced cloud-init failures. The Auto Scaling Group was creating instances, but the application was not being installed correctly and the expected systemd service was not being created.

I investigated the instances directly using Linux tools and examined:

```text
/var/log/cloud-init-output.log
/var/lib/cloud/instance/scripts/part-001
```

This exposed formatting and scripting problems in the generated User Data.

The bootstrap process was rewritten with:

- Explicit logging
- Cleaner Bash heredocs
- Correct Python indentation
- Correct exception handling
- More defensive service startup
- systemd service creation
- Clear installation-stage markers

After deploying the corrected Launch Template, an Auto Scaling instance refresh successfully replaced the previous instances.

Final result:

```text
2/2 EC2 instances
Healthy
InService
Launch Template Version 7
```

The Application Load Balancer then successfully served the application, and the `/health` endpoint confirmed database connectivity.

This troubleshooting process provided hands-on experience with the relationship between Terraform, EC2 Launch Templates, cloud-init, systemd, Auto Scaling health checks, and load balancer health checks.

## Current Result

The Terraform-managed environment successfully demonstrates:

```text
Internet
   ↓
Application Load Balancer
   ↓
Auto Scaling Group
   ↓
2 × EC2
   ↓
Flask / Gunicorn
   ↓
Secrets Manager
   ↓
RDS PostgreSQL
```

The infrastructure was successfully deployed, validated, troubleshot, and rebuilt through Terraform.

## Future Improvements

Potential future iterations include:

- NAT Gateway or alternative private-subnet outbound architecture
- HTTPS using ACM
- Route 53 DNS
- CloudWatch dashboards and alarms
- Centralized application logging
- Remote Terraform state using S3
- DynamoDB state locking where appropriate
- Terraform modules
- CI/CD with GitHub Actions or AWS CodePipeline
- Automated testing
- Blue/green or rolling application deployments
- Containerized application deployment

## Technologies

**Cloud**

- AWS EC2
- AWS VPC
- AWS Application Load Balancer
- AWS Auto Scaling
- Amazon RDS
- AWS Secrets Manager
- AWS IAM

**Infrastructure as Code**

- Terraform
- AWS Provider

**Application**

- Python
- Flask
- Gunicorn
- PostgreSQL
- systemd

**Tools**

- Linux
- Bash
- AWS CLI
- Git
- GitHub
