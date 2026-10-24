# Scalable AWS Web Application with Terraform & AWS CI/CD

A highly available, horizontally scalable web application deployed on AWS and managed through Terraform, with an automated CI/CD pipeline using AWS CodePipeline, CodeBuild, and CodeDeploy.

This project was built to gain hands-on experience designing, deploying, troubleshooting, and automating a production-style cloud environment using core AWS services and Infrastructure as Code.

The application runs on Amazon EC2 behind an Application Load Balancer and Auto Scaling Group, uses Amazon RDS PostgreSQL for persistent data, and retrieves database credentials securely from AWS Secrets Manager.

Infrastructure changes are managed with Terraform, while application deployments are automated through an AWS-native CI/CD pipeline connected to GitHub.

## Architecture

![AWS Scalable Web Application Architecture](architecture.png)

CI/CD Workflow

GitHub
   ↓
AWS CodePipeline
   ↓
AWS CodeBuild
   ↓
AWS CodeDeploy
   ↓
Auto Scaling Group
   ↓
EC2 Instances
   ↓
Application Load Balancer
   ↓
Flask Application
   ↓
RDS PostgreSQL

Terraform manages the underlying AWS infrastructure, while CodePipeline automates the application deployment workflow from GitHub through CodeBuild and CodeDeploy.

What This Project Demonstrates

AWS VPC and subnet architecture

Multi-AZ infrastructure

Public and private subnet separation

Application Load Balancing

EC2 Auto Scaling

Launch Templates

PostgreSQL on Amazon RDS

AWS Secrets Manager

IAM roles and least-privilege access

Security groups and network-level access control

Flask and Gunicorn

Linux systemd services

Infrastructure as Code with Terraform

AWS CodePipeline

AWS CodeBuild

AWS CodeDeploy

GitHub integration through AWS CodeConnections

Automated application deployments

Health checks and automated instance replacement

AWS CLI troubleshooting

Git and GitHub workflow

AWS Infrastructure

Networking

The infrastructure is deployed in the us-east-2 AWS region using a dedicated VPC with the following layout:

VPC CIDR: 10.0.0.0/16

2 public subnets across separate Availability Zones

2 private subnets across separate Availability Zones

Internet Gateway

Public route table

Private subnets for the RDS database

EC2 instances are deployed in the public subnets to avoid the additional cost of a NAT Gateway. Application access is still restricted through security groups and the Application Load Balancer.

Compute

The application runs on Amazon Linux 2023 EC2 instances using:

t3.micro instances

10 GiB encrypted gp3 root volumes

Python 3

Flask

Gunicorn

systemd

IAM instance profile

AWS CodeDeploy agent

EC2 instances are managed by an Auto Scaling Group configured with:

Minimum: 2 instances

Desired: 2 instances

Maximum: 4 instances

Target CPU utilization: 60%

Elastic Load Balancing health checks

Launch Template version 9

The Launch Template uses User Data for initial instance configuration, including package installation, application dependencies, systemd configuration, and CodeDeploy agent installation.

Load Balancing

An internet-facing Application Load Balancer distributes traffic across the EC2 instances.

Internet
   ↓
Application Load Balancer
   ↓
Target Group
   ↓
EC2 Instances :8000

The ALB listens on port 80 and forwards traffic to the application target group on port 8000.

Health checks use:

Protocol: HTTP

Port: traffic-port

Path: /health

Expected response: 200

This allows unhealthy instances to be detected and replaced automatically by the Auto Scaling Group.

Database

The application uses Amazon RDS PostgreSQL for persistent data.

Configuration includes:

PostgreSQL 17

db.t3.micro

20 GB gp3 storage

Encryption at rest

Single-AZ deployment

Public access disabled

Private subnets

Database security group restricting PostgreSQL traffic to the EC2 security group

The Flask application connects to the database at runtime using credentials retrieved from AWS Secrets Manager.

Secrets Management

Database credentials are stored in AWS Secrets Manager rather than being hard-coded into the application or Terraform configuration.

The EC2 instance uses an IAM role to retrieve the secret at runtime through:

secretsmanager:GetSecretValue

The IAM policy is scoped specifically to the application's database credential secret.

This avoids storing long-lived database credentials directly in the application code or Git repository.

Application

The application is a Flask-based server inventory application.

It provides:

Server ID

Hostname

Environment

Status

IP address

The application exposes:

/

for the server inventory interface and:

/health

for application and database health validation.

The application runs through Gunicorn and is managed as a Linux systemd service.

Infrastructure as Code

The AWS infrastructure is managed using Terraform.

Terraform Structure

provider.tf
variables.tf
networking.tf
security-groups.tf
database.tf
iam.tf
compute.tf
load-balancer.tf
autoscaling.tf
outputs.tf

Terraform is responsible for provisioning and managing:

VPC networking

Subnets

Route tables

Internet Gateway

Security groups

RDS PostgreSQL

IAM roles and policies

EC2 Launch Template

Auto Scaling Group

Application Load Balancer

Target Group

Listeners

Typical Terraform workflow:

terraform init
terraform validate
terraform plan
terraform apply

Terraform configuration is validated as part of the CI/CD build process.

CI/CD Pipeline

Application deployments are automated using AWS-native CI/CD services.

Pipeline

GitHub
   ↓
AWS CodePipeline
   ↓
AWS CodeBuild
   ↓
AWS CodeDeploy
   ↓
EC2 / Auto Scaling Group

Source

AWS CodePipeline is connected to the GitHub repository through AWS CodeConnections.

Changes pushed to the main branch automatically trigger the pipeline.

Build

AWS CodeBuild performs validation and prepares the deployment artifact.

The build process:

Installs required build dependencies

Initializes Terraform without a backend

Runs terraform fmt -check

Runs terraform validate

Verifies required project files exist

Packages the repository as the deployment artifact

The build configuration is defined in:

buildspec.yml

Deployment

AWS CodeDeploy deploys the application artifact to the EC2 instances managed by the Auto Scaling Group.

The deployment configuration is defined in:

appspec.yml

Deployment lifecycle hooks include:

ApplicationStop
      ↓
BeforeInstall
      ↓
Install
      ↓
ApplicationStart
      ↓
ValidateService

The deployment scripts handle stopping the existing application, cleaning the deployment directory, starting the systemd service, and validating that the application is running.

Deployment Scripts

scripts/
├── cleanup_application.sh
├── stop_application.sh
├── start_application.sh
└── validate_service.sh

This allows application deployments to be performed consistently across multiple EC2 instances.

Security Considerations

Security was considered throughout the infrastructure design.

RDS is not publicly accessible

Database traffic is restricted to the EC2 security group

Application traffic is routed through the Application Load Balancer

EC2 instances use IAM roles rather than long-lived AWS credentials

Database credentials are stored in Secrets Manager

Secrets Manager permissions are scoped to the application secret

Security groups restrict access between infrastructure components

Terraform variables containing sensitive values are excluded from Git

Terraform state files are excluded from Git

Database passwords are not stored in the repository

SSH access was used for troubleshooting and is not part of the application's normal request path

Troubleshooting & Lessons Learned

One of the main goals of this project was gaining practical experience troubleshooting AWS infrastructure rather than simply deploying a working configuration.

EC2 Bootstrap and Cloud-Init

Early versions of the infrastructure experienced issues during EC2 initialization.

Troubleshooting involved reviewing:

/var/log/cloud-init-output.log

and:

/var/lib/cloud/instance/scripts/

The User Data configuration was eventually rewritten with explicit logging, clearer installation stages, defensive error handling, and a systemd-managed application service.

This made future instance launches easier to troubleshoot and helped ensure the application could reliably start as part of the instance lifecycle.

CodeDeploy Disk Space Failure

An early CodeDeploy deployment failed with:

No space left on device
(os error 28)

The original EC2 Launch Template used a 2 GiB root volume, which was insufficient for the CodeDeploy deployment process and application artifacts.

The Launch Template was updated to use a:

10 GiB encrypted gp3

root volume.

The Auto Scaling Group was then refreshed so that new instances launched with the updated configuration.

The subsequent instance refresh completed successfully.

CodeDeploy File Conflict

After resolving the disk space issue, CodeDeploy encountered another deployment failure because:

/home/ec2-user/scalable-web-app/app.py

already existed on the target instance.

The deployment process was updated with a BeforeInstall cleanup hook that removes the previous application directory before CodeDeploy installs the new revision.

This resulted in a clean deployment lifecycle for subsequent releases.

CI/CD Validation

The final pipeline was successfully validated end-to-end:

Source   → Succeeded
Build    → Succeeded
Deploy   → Succeeded

The deployment successfully delivered the application from GitHub through AWS CodePipeline, CodeBuild, and CodeDeploy to the EC2 instances behind the Auto Scaling Group.

Both EC2 instances were healthy and registered with the Application Load Balancer following the deployment.

Current Result

The final environment consists of:

GitHub
   ↓
AWS CodePipeline
   ↓
AWS CodeBuild
   ↓
AWS CodeDeploy
   ↓
Auto Scaling Group
   ↓
2 × EC2 Instances
   ↓
Application Load Balancer
   ↓
Flask / Gunicorn
   ↓
AWS Secrets Manager
   ↓
RDS PostgreSQL

Terraform manages the AWS infrastructure, while the CI/CD pipeline automates application delivery.

The project has been deployed, tested, troubleshot, and successfully validated as a working end-to-end AWS environment.

Future Improvements

Potential future improvements include:

HTTPS with AWS Certificate Manager

Route 53 DNS

CloudWatch dashboards and additional alarms

Centralized application logging

Remote Terraform state using Amazon S3 and state locking

Reusable Terraform modules

Automated application testing

Blue/green or rolling deployment strategies

Containerizing the Flask application

Further infrastructure hardening

Technologies

Cloud

Amazon EC2

Amazon VPC

Application Load Balancer

Auto Scaling

Amazon RDS

AWS Secrets Manager

AWS IAM

AWS CodePipeline

AWS CodeBuild

AWS CodeDeploy

AWS CodeConnections

Infrastructure as Code

Terraform

HashiCorp AWS Provider

Application

Python

Flask

Gunicorn

PostgreSQL

Linux systemd

Tools

Linux

Bash

AWS CLI

Git

GitHub

Terraform
