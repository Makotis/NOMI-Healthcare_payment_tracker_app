#!/bin/bash

# Healthcare Payment Tracker - EC2 User Data Script
# This script automatically sets up the application on EC2 instance launch

# Update system packages
yum update -y

# Install Docker
yum install -y docker
service docker start
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Git
yum install -y git

# Install CloudWatch agent
yum install -y amazon-cloudwatch-agent

# Create application directory
mkdir -p /opt/healthcare-app
cd /opt/healthcare-app

# Create application files
cat > index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Healthcare Payment Tracker</title>
    <link rel="stylesheet" href="styles.css">
</head>
<body>
    <div class="app-container">
        <header class="app-header">
            <h1>Healthcare Payment Tracker</h1>
            <div class="user-info">
                <span>Welcome, John Doe</span>
                <button class="btn btn-secondary">Settings</button>
            </div>
        </header>

        <nav class="sidebar">
            <ul class="nav-menu">
                <li><a href="#dashboard" class="nav-link active" data-tab="dashboard">Dashboard</a></li>
                <li><a href="#payments" class="nav-link" data-tab="payments">Payment History</a></li>
                <li><a href="#add-payment" class="nav-link" data-tab="add-payment">Add Payment</a></li>
                <li><a href="#providers" class="nav-link" data-tab="providers">Providers</a></li>
                <li><a href="#reports" class="nav-link" data-tab="reports">Reports</a></li>
            </ul>
        </nav>

        <main class="main-content">
            <!-- Dashboard Tab -->
            <div id="dashboard" class="tab-content active">
                <div class="dashboard-grid">
                    <div class="stat-card">
                        <h3>Total Payments</h3>
                        <div class="stat-value" id="total-payments">$0</div>
                        <div class="stat-change positive">+12% this month</div>
                    </div>
                    <div class="stat-card">
                        <h3>Pending Claims</h3>
                        <div class="stat-value" id="pending-claims">0</div>
                        <div class="stat-change negative">3 overdue</div>
                    </div>
                    <div class="stat-card">
                        <h3>Insurance Coverage</h3>
                        <div class="stat-value" id="coverage-percent">85%</div>
                        <div class="stat-change">Average coverage</div>
                    </div>
                    <div class="stat-card">
                        <h3>Outstanding Balance</h3>
                        <div class="stat-value" id="outstanding-balance">$0</div>
                        <div class="stat-change">Due within 30 days</div>
                    </div>
                </div>

                <div class="recent-payments">
                    <h2>Recent Payments</h2>
                    <div class="payment-list" id="recent-payments-list"></div>
                </div>
            </div>

            <!-- Payment History Tab -->
            <div id="payments" class="tab-content">
                <div class="payments-header">
                    <h2>Payment History</h2>
                    <div class="filters">
                        <select id="status-filter">
                            <option value="all">All Status</option>
                            <option value="paid">Paid</option>
                            <option value="pending">Pending</option>
                            <option value="overdue">Overdue</option>
                        </select>
                        <select id="provider-filter">
                            <option value="all">All Providers</option>
                        </select>
                        <input type="date" id="date-filter" placeholder="Filter by date">
                    </div>
                </div>
                <div class="payment-table-container">
                    <table class="payment-table">
                        <thead>
                            <tr>
                                <th>Date</th>
                                <th>Provider</th>
                                <th>Service</th>
                                <th>Amount</th>
                                <th>Insurance</th>
                                <th>Your Cost</th>
                                <th>Status</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody id="payments-table-body"></tbody>
                    </table>
                </div>
            </div>

            <!-- Add Payment Tab -->
            <div id="add-payment" class="tab-content">
                <div class="form-container">
                    <h2>Add New Payment</h2>
                    <form id="payment-form">
                        <div class="form-group">
                            <label for="service-date">Service Date</label>
                            <input type="date" id="service-date" required>
                        </div>
                        <div class="form-group">
                            <label for="provider-select">Provider</label>
                            <select id="provider-select" required>
                                <option value="">Select Provider</option>
                            </select>
                        </div>
                        <div class="form-group">
                            <label for="service-type">Service Type</label>
                            <input type="text" id="service-type" placeholder="e.g., Annual Checkup" required>
                        </div>
                        <div class="form-group">
                            <label for="total-amount">Total Amount</label>
                            <input type="number" id="total-amount" step="0.01" placeholder="0.00" required>
                        </div>
                        <div class="form-group">
                            <label for="insurance-coverage">Insurance Coverage</label>
                            <input type="number" id="insurance-coverage" step="0.01" placeholder="0.00">
                        </div>
                        <div class="form-group">
                            <label for="payment-status">Payment Status</label>
                            <select id="payment-status" required>
                                <option value="pending">Pending</option>
                                <option value="paid">Paid</option>
                                <option value="overdue">Overdue</option>
                            </select>
                        </div>
                        <div class="form-group">
                            <label for="notes">Notes</label>
                            <textarea id="notes" rows="3" placeholder="Additional notes..."></textarea>
                        </div>
                        <button type="submit" class="btn btn-primary">Add Payment</button>
                    </form>
                </div>
            </div>

            <!-- Providers Tab -->
            <div id="providers" class="tab-content">
                <div class="providers-header">
                    <h2>Healthcare Providers</h2>
                    <button class="btn btn-primary" id="add-provider-btn">Add Provider</button>
                </div>
                <div class="providers-grid" id="providers-grid"></div>
            </div>

            <!-- Reports Tab -->
            <div id="reports" class="tab-content">
                <div class="reports-header">
                    <h2>Payment Reports</h2>
                    <button class="btn btn-secondary" id="export-btn">Export Data</button>
                </div>
                <div class="reports-grid">
                    <div class="chart-container">
                        <h3>Monthly Spending</h3>
                        <div class="chart-placeholder">Chart visualization would go here</div>
                    </div>
                    <div class="chart-container">
                        <h3>Provider Breakdown</h3>
                        <div class="chart-placeholder">Provider spending chart</div>
                    </div>
                </div>
            </div>
        </main>
    </div>

    <script src="app.js"></script>
</body>
</html>
EOF

# Copy other application files from the existing codebase
# (In a real scenario, you would fetch these from your repository)

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  healthcare-app:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: healthcare-payment-tracker
    ports:
      - "8080:80"
    restart: unless-stopped
    networks:
      - healthcare-network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.healthcare-app.rule=Host(`localhost`)"
      - "traefik.http.services.healthcare-app.loadbalancer.server.port=80"

networks:
  healthcare-network:
    driver: bridge

volumes:
  healthcare-data:
    driver: local
EOF

# Create Dockerfile
cat > Dockerfile << 'EOF'
FROM nginx:alpine

# Remove default nginx website
RUN rm -rf /usr/share/nginx/html/*

# Copy our app files to nginx html directory
COPY index.html /usr/share/nginx/html/
COPY app.js /usr/share/nginx/html/
COPY styles.css /usr/share/nginx/html/

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
EOF

# Create nginx configuration
cat > nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log warn;

    # Performance settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1000;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    server {
        listen 80;
        server_name localhost;
        root /usr/share/nginx/html;
        index index.html;

        # Security
        server_tokens off;

        # Main application
        location / {
            try_files $uri $uri/ /index.html;
            
            # Cache static assets
            location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
                expires 1y;
                add_header Cache-Control "public, immutable";
            }
        }

        # Health check endpoint
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }

        # Error pages
        error_page 404 /index.html;
        error_page 500 502 503 504 /50x.html;
        
        location = /50x.html {
            root /usr/share/nginx/html;
        }
    }
}
EOF

# Set proper ownership
chown -R ec2-user:ec2-user /opt/healthcare-app

# Start Docker on boot
chkconfig docker on

# Build and start the application
cd /opt/healthcare-app
sudo -u ec2-user docker-compose up -d --build

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
    "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "cwagent"
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/messages",
                        "log_group_name": "/aws/ec2/healthcare-app/system",
                        "log_stream_name": "{instance_id}-messages"
                    },
                    {
                        "file_path": "/var/log/docker",
                        "log_group_name": "/aws/ec2/healthcare-app/docker",
                        "log_stream_name": "{instance_id}-docker"
                    }
                ]
            }
        }
    },
    "metrics": {
        "namespace": "CWAgent",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60,
                "totalcpu": false
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "diskio": {
                "measurement": [
                    "io_time"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            },
            "netstat": {
                "measurement": [
                    "tcp_established",
                    "tcp_time_wait"
                ],
                "metrics_collection_interval": 60
            },
            "swap": {
                "measurement": [
                    "swap_used_percent"
                ],
                "metrics_collection_interval": 60
            }
        }
    }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -s \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# Create a startup script for automatic recovery
cat > /etc/init.d/healthcare-app << 'EOF'
#!/bin/bash
# Healthcare Payment Tracker startup script
# chkconfig: 35 99 99
# description: Healthcare Payment Tracker

. /etc/rc.d/init.d/functions

USER="ec2-user"
DAEMON="healthcare-app"
ROOT_DIR="/opt/healthcare-app"

SERVER="$ROOT_DIR/docker-compose"
LOCK_FILE="/var/lock/subsys/healthcare-app"

do_start() {
    if [ ! -f "$LOCK_FILE" ] ; then
        echo -n $"Starting $DAEMON: "
        runuser -l "$USER" -c "$ROOT_DIR" && echo && touch $LOCK_FILE
    fi
}
do_stop() {
    echo -n $"Shutting down $DAEMON: "
    pid=`ps -aefw | grep DAEMON | grep -v " grep " | awk '{print $2}'`
    kill -9 $pid > /dev/null 2>&1
    [ $? -eq 0 ] && echo "OK" || echo "FAIL"
    rm -f $LOCK_FILE
}

case "$1" in
    start)
        do_start
        ;;
    stop)
        do_stop
        ;;
    restart)
        do_stop
        do_start
        ;;
    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 1
esac

exit 0
EOF

chmod +x /etc/init.d/healthcare-app
chkconfig --add healthcare-app
chkconfig healthcare-app on

# Create log rotation for application logs
cat > /etc/logrotate.d/healthcare-app << 'EOF'
/opt/healthcare-app/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    copytruncate
}
EOF

# Create monitoring script
cat > /opt/healthcare-app/monitor.sh << 'EOF'
#!/bin/bash
# Simple monitoring script for Healthcare Payment Tracker

LOG_FILE="/opt/healthcare-app/logs/monitor.log"
mkdir -p /opt/healthcare-app/logs

check_container() {
    if docker ps | grep -q healthcare-payment-tracker; then
        echo "$(date): Container is running" >> $LOG_FILE
        return 0
    else
        echo "$(date): Container is not running, attempting restart" >> $LOG_FILE
        cd /opt/healthcare-app
        docker-compose up -d
        return 1
    fi
}

check_health() {
    if curl -f http://localhost:8080/health > /dev/null 2>&1; then
        echo "$(date): Health check passed" >> $LOG_FILE
        return 0
    else
        echo "$(date): Health check failed" >> $LOG_FILE
        return 1
    fi
}

# Run checks
check_container
sleep 30
check_health

# If health check fails, restart container
if [ $? -ne 0 ]; then
    echo "$(date): Restarting container due to health check failure" >> $LOG_FILE
    cd /opt/healthcare-app
    docker-compose restart
fi
EOF

chmod +x /opt/healthcare-app/monitor.sh

# Add monitoring to crontab
(crontab -l 2>/dev/null; echo "*/5 * * * * /opt/healthcare-app/monitor.sh") | crontab -

# Setup automatic security updates
yum install -y yum-cron
sed -i 's/apply_updates = no/apply_updates = yes/' /etc/yum/yum-cron.conf
service yum-cron start
chkconfig yum-cron on

# Install fail2ban for security
yum install -y fail2ban
service fail2ban start
chkconfig fail2ban on

echo "Healthcare Payment Tracker setup completed successfully!"
echo "Application will be available at http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"