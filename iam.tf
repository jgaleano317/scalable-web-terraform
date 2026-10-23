resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "scalable-web-db-credentials-tf"
  description = "Credentials for the scalable web application PostgreSQL database"

  tags = {
    Name = "scalable-web-db-credentials-tf"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    username = "postgres"
    password = var.db_password
  })
}


resource "aws_iam_role" "ec2" {
  name = "scalable-web-ec2-role-tf"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "scalable-web-ec2-role-tf"
  }
}


resource "aws_iam_policy" "secrets_read" {
  name        = "scalable-web-secrets-read-tf"
  description = "Allow EC2 to read the database credentials secret"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "secretsmanager:GetSecretValue"
        ]

        Resource = aws_secretsmanager_secret.db_credentials.arn
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "secrets_read" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.secrets_read.arn
}


resource "aws_iam_instance_profile" "ec2" {
  name = "scalable-web-ec2-profile-tf"
  role = aws_iam_role.ec2.name
}
