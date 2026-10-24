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
