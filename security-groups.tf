# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "scalable-alb-sg-tf"
  description = "Allow HTTP traffic from the internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "scalable-alb-sg-tf"
  }
}


# EC2 Security Group
resource "aws_security_group" "ec2" {
  name        = "scalable-ec2-sg-tf"
  description = "Allow application traffic from the ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Gunicorn traffic from ALB"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "scalable-ec2-sg-tf"
  }
}


# RDS Security Group
resource "aws_security_group" "rds" {
  name        = "scalable-rds-sg-tf"
  description = "Allow PostgreSQL traffic from application servers"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "scalable-rds-sg-tf"
  }
}
