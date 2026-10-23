data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_launch_template" "web" {
  name        = "scalable-web-launch-template-tf"
  description = "Launch template for the scalable Flask web application"

  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  key_name = "scalable-web-key"

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  vpc_security_group_ids = [
    aws_security_group.ec2.id
  ]

  user_data = base64encode(<<-EOF
#!/bin/bash

exec > >(tee /var/log/scalable-web-user-data.log | logger -t scalable-web-user-data -s 2>/dev/console) 2>&1

echo "=== USER DATA START ==="

echo "=== Installing packages ==="
dnf update -y
dnf install -y python3 python3-pip postgresql15
echo "=== Package installation complete ==="

echo "=== Creating application directory ==="
mkdir -p /home/ec2-user/scalable-web-app
chown -R ec2-user:ec2-user /home/ec2-user/scalable-web-app
echo "=== Directory created ==="

echo "=== Creating Python virtual environment ==="
sudo -u ec2-user python3 -m venv /home/ec2-user/scalable-web-app/venv
echo "=== Virtual environment created ==="

echo "=== Installing Python packages ==="
sudo -u ec2-user /home/ec2-user/scalable-web-app/venv/bin/pip install Flask psycopg2-binary boto3 gunicorn
echo "=== Python packages installed ==="

echo "=== Creating Flask application ==="

cat <<'PYTHON' > /home/ec2-user/scalable-web-app/app.py
from flask import Flask
import os
import json
import boto3
import psycopg2

app = Flask(__name__)


def get_db_credentials():
    client = boto3.client(
        "secretsmanager",
        region_name="us-east-2"
    )

    response = client.get_secret_value(
        SecretId="scalable-web-db-credentials-tf"
    )

    return json.loads(response["SecretString"])


def get_db_connection():
    credentials = get_db_credentials()

    return psycopg2.connect(
        host=os.environ["DB_HOST"],
        port=os.environ["DB_PORT"],
        dbname=os.environ["DB_NAME"],
        user=credentials["username"],
        password=credentials["password"],
        connect_timeout=5
    )


def initialize_database():
    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("""
        CREATE TABLE IF NOT EXISTS servers (
            id SERIAL PRIMARY KEY,
            hostname VARCHAR(100) NOT NULL,
            environment VARCHAR(50) NOT NULL,
            status VARCHAR(50) NOT NULL,
            ip_address VARCHAR(45)
        );
    """)

    cur.execute("SELECT COUNT(*) FROM servers;")
    count = cur.fetchone()[0]

    if count == 0:
        cur.execute("""
            INSERT INTO servers (
                hostname,
                environment,
                status,
                ip_address
            )
            VALUES
                ('web-server-01', 'production', 'running', '10.0.1.91'),
                ('web-server-02', 'production', 'running', '10.0.2.25'),
                ('web-server-03', 'staging', 'stopped', '10.0.2.26');
        """)

    conn.commit()
    cur.close()
    conn.close()


@app.route("/")
def home():
    try:
        initialize_database()

        conn = get_db_connection()
        cur = conn.cursor()

        cur.execute("""
            SELECT
                id,
                hostname,
                environment,
                status,
                ip_address
            FROM servers
            ORDER BY id;
        """)

        servers = cur.fetchall()

        cur.close()
        conn.close()

        html = """
        <html>
            <head>
                <title>Server Inventory</title>
            </head>
            <body>
                <h1>Scalable Web App</h1>
                <h2>Server Inventory</h2>

                <table border="1" cellpadding="8">
                    <tr>
                        <th>ID</th>
                        <th>Hostname</th>
                        <th>Environment</th>
                        <th>Status</th>
                        <th>IP Address</th>
                    </tr>
        """

        for server in servers:
            html += f"""
                    <tr>
                        <td>{server[0]}</td>
                        <td>{server[1]}</td>
                        <td>{server[2]}</td>
                        <td>{server[3]}</td>
                        <td>{server[4]}</td>
                    </tr>
            """

        html += """
                </table>
            </body>
        </html>
        """

        return html

    except Exception as e:
        return f"Application error: {str(e)}", 500


@app.route("/health")
def health():
    try:
        conn = get_db_connection()
        cur = conn.cursor()

        cur.execute("SELECT 1;")
        cur.fetchone()

        cur.close()
        conn.close()

        return "healthy - database connection successful", 200

    except Exception as e:
        print(f"Database health check failed: {e}")
        return "unhealthy - database connection failed", 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
PYTHON

echo "=== Flask application created ==="

chown ec2-user:ec2-user /home/ec2-user/scalable-web-app/app.py

echo "=== Creating systemd service ==="

cat <<SERVICE > /etc/systemd/system/scalable-web-app.service
[Unit]
Description=Scalable Web App
After=network.target

[Service]
User=ec2-user
Group=ec2-user
WorkingDirectory=/home/ec2-user/scalable-web-app

Environment="DB_HOST=${aws_db_instance.postgres.address}"
Environment="DB_PORT=5432"
Environment="DB_NAME=postgres"

ExecStart=/home/ec2-user/scalable-web-app/venv/bin/gunicorn --bind 0.0.0.0:8000 app:app

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

echo "=== Systemd service created ==="

systemctl daemon-reload
systemctl enable scalable-web-app

echo "=== Starting application ==="
systemctl start scalable-web-app || true

echo "=== Application service status ==="
systemctl status scalable-web-app --no-pager || true

echo "=== USER DATA COMPLETE ==="
EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "scalable-web-app-tf"
    }
  }

  tags = {
    Name = "scalable-web-launch-template-tf"
  }
}
