# Healthcare Payment Tracker - AWS Deployment Guide

This guide provides comprehensive instructions for deploying the Healthcare Payment Tracker application on Amazon Web Services (AWS) with HTTPS support using Traefik reverse proxy and Let's Encrypt certificates.

## 🌐 Production Example
**Live Application:** [https://nomi.payment.ats-victorycenter.org](https://nomi.payment.ats-victorycenter.org)
**Traefik Dashboard:** [https://traefik.nomi.payment.ats-victorycenter.org](https://traefik.nomi.payment.ats-victorycenter.org)

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Deployment Options Overview](#deployment-options-overview)
- [Option 1: EC2 with Traefik HTTPS (Recommended)](#option-1-ec2-with-traefik-https-recommended)
- [Option 2: ECS Fargate with ALB](#option-2-ecs-fargate-with-alb)
- [Option 3: S3 Static Hosting with CloudFront](#option-3-s3-static-hosting-with-cloudfront)
- [Option 4: AWS App Runner](#option-4-aws-app-runner)
- [SSL Certificate Management](#ssl-certificate-management)
- [Cost Optimization](#cost-optimization)
- [Monitoring and Logging](#monitoring-and-logging)
- [Security Considerations](#security-considerations)
- [Troubleshooting](#troubleshooting)

## 🎯 Prerequisites

### Required Tools
- **AWS CLI** installed and configured
- **Docker** installed locally
- **AWS Account** with appropriate permissions
- **Domain name** (required for HTTPS with Let's Encrypt)
- **DNS management access** (Route 53 or external provider)

### AWS CLI Setup
```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure credentials
aws configure
# Enter your Access Key ID, Secret Access Key, Region (e.g., us-east-1)
```

### Required AWS Permissions
Your AWS user needs the following services:
- **ECS** (Elastic Container Service)
- **ECR** (Elastic Container Registry)
- **VPC** (Virtual Private Cloud)
- **IAM** (Identity and Access Management)
- **CloudWatch** (Monitoring)
- **Application Load Balancer**
- **Route 53** (if using custom domain)

## 🚀 Deployment Options Overview

| Option | Complexity | Cost | Scalability | HTTPS | Use Case |
|--------|------------|------|-------------|-------|----------|
| **EC2 + Traefik** | Low | $8-15/month | Medium | Auto SSL | Production with domains |
| **ECS Fargate** | Medium | $15-30/month | High | ALB SSL | Enterprise environments |
| **S3 + CloudFront** | Low | $2-5/month | High | CloudFront SSL | Static hosting only |
| **App Runner** | Low | $20-40/month | High | Built-in SSL | Simplest deployment |

## 🏗️ Option 1: EC2 with Traefik HTTPS (Recommended)

This option provides automatic HTTPS certificates with Traefik reverse proxy on a single EC2 instance.

### Step 1: Launch EC2 Instance with Traefik Setup

```bash
# Launch EC2 instance
aws ec2 run-instances \
    --image-id ami-0c02fb55956c7d316 \
    --count 1 \
    --instance-type t3.small \
    --key-name your-key-pair \
    --security-group-ids sg-12345 \
    --user-data file://traefik-user-data.sh \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=healthcare-traefik-server}]'
```

### Step 2: Create Enhanced User Data Script

Create `traefik-user-data.sh`:
```bash
#!/bin/bash

# Healthcare Payment Tracker with Traefik HTTPS - EC2 Setup
set -e

# Configuration
DOMAIN="your-domain.com"  # Replace with your domain
EMAIL="your-email@domain.com"  # Replace with your email

# Update system
yum update -y

# Install Docker
yum install -y docker git
service docker start
usermod -a -G docker ec2-user
systemctl enable docker

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create application directory
mkdir -p /opt/healthcare-app
cd /opt/healthcare-app

# Clone the repository (replace with your repo URL)
git clone https://github.com/your-username/healthcare-payment-tracker.git .

# Update domain in docker-compose.yml
sed -i "s/nomi.payment.ats-victorycenter.org/$DOMAIN/g" docker-compose.yml

# Update email in traefik.yml
sed -i "s/admin@ats-victorycenter.org/$EMAIL/g" traefik.yml

# Create Traefik network
docker network create traefik

# Set up SSL certificate file
touch acme.json
chmod 600 acme.json

# Start the application
docker-compose up -d --build

# Setup monitoring and logging
cat > /etc/logrotate.d/docker-logs << EOF
/var/lib/docker/containers/*/*-json.log {
  daily
  rotate 7
  compress
  delaycompress
  missingok
  notifempty
  create 644 root root
}
EOF

# Create startup script
cat > /etc/systemd/system/healthcare-app.service << EOF
[Unit]
Description=Healthcare Payment Tracker
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/healthcare-app
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl enable healthcare-app.service

echo "Healthcare Payment Tracker with HTTPS deployed successfully!"
echo "Access your application at: https://$DOMAIN"
echo "Traefik dashboard at: https://traefik.$DOMAIN"
```

### Step 3: Configure Security Group

```bash
# Create security group for HTTPS
aws ec2 create-security-group \
    --group-name healthcare-https-sg \
    --description "Healthcare Payment Tracker with HTTPS"

# Get security group ID
SG_ID=$(aws ec2 describe-security-groups \
    --group-names healthcare-https-sg \
    --query 'SecurityGroups[0].GroupId' \
    --output text)

# Allow HTTP (for Let's Encrypt challenge)
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0

# Allow HTTPS
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0

# Allow SSH
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 22 \
    --cidr your.ip.address/32

# Allow Traefik Dashboard (optional, restrict to your IP)
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 8080 \
    --cidr your.ip.address/32
```

### Step 4: Route 53 DNS Configuration

```bash
# Create hosted zone (if not exists)
aws route53 create-hosted-zone \
    --name yourdomain.com \
    --caller-reference $(date +%s)

# Get hosted zone ID
ZONE_ID=$(aws route53 list-hosted-zones \
    --query "HostedZones[?Name=='yourdomain.com.'].Id" \
    --output text | cut -d'/' -f3)

# Get EC2 instance public IP
INSTANCE_IP=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=healthcare-traefik-server" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

# Create A record for main domain
cat > dns-record.json << EOF
{
    "Changes": [
        {
            "Action": "CREATE",
            "ResourceRecordSet": {
                "Name": "yourdomain.com",
                "Type": "A",
                "TTL": 300,
                "ResourceRecords": [
                    {
                        "Value": "$INSTANCE_IP"
                    }
                ]
            }
        },
        {
            "Action": "CREATE",
            "ResourceRecordSet": {
                "Name": "traefik.yourdomain.com",
                "Type": "A",
                "TTL": 300,
                "ResourceRecords": [
                    {
                        "Value": "$INSTANCE_IP"
                    }
                ]
            }
        }
    ]
}
EOF

aws route53 change-resource-record-sets \
    --hosted-zone-id $ZONE_ID \
    --change-batch file://dns-record.json
```

### Step 5: Deployment Verification

```bash
# SSH into your instance
ssh -i your-key.pem ec2-user@$INSTANCE_IP

# Check services
docker-compose ps

# Check logs
docker-compose logs -f traefik
docker-compose logs -f healthcare-app

# Test HTTPS
curl -I https://yourdomain.com
```

## 🔐 SSL Certificate Management

### Let's Encrypt with Traefik

Traefik automatically manages SSL certificates using Let's Encrypt:

```bash
# Check certificate status
docker exec -it traefik traefik version

# View certificate details in acme.json
docker exec -it traefik cat /acme.json | jq '.letsencrypt.Certificates[0].domain'

# Force certificate renewal (if needed)
docker exec -it traefik rm /acme.json
docker-compose restart traefik
```

### Manual Certificate Verification

```bash
# Check certificate expiry
openssl s_client -connect yourdomain.com:443 -servername yourdomain.com 2>/dev/null | openssl x509 -noout -dates

# Test SSL configuration
curl -I https://yourdomain.com

# SSL Labs test (external)
# Visit: https://www.ssllabs.com/ssltest/analyze.html?d=yourdomain.com
```

### Certificate Monitoring Script

```bash
cat > /opt/healthcare-app/monitor_ssl.sh << 'EOF'
#!/bin/bash
DOMAIN="yourdomain.com"
DAYS_UNTIL_EXPIRY=$(echo | openssl s_client -connect $DOMAIN:443 -servername $DOMAIN 2>/dev/null | openssl x509 -noout -checkend $((30*24*3600)) && echo "Certificate is valid for more than 30 days" || echo "Certificate expires within 30 days!")

echo "$(date): $DAYS_UNTIL_EXPIRY" >> /var/log/ssl-monitor.log

if [[ $DAYS_UNTIL_EXPIRY == *"expires within"* ]]; then
    # Send alert (configure with your notification method)
    echo "SSL Certificate expiring soon for $DOMAIN" | wall
fi
EOF

chmod +x /opt/healthcare-app/monitor_ssl.sh

# Add to crontab to run daily
(crontab -l 2>/dev/null; echo "0 6 * * * /opt/healthcare-app/monitor_ssl.sh") | crontab -
```

## 🏗️ Option 2: ECS Fargate with ALB

### Step 1: Create ECR Repository

```bash
# Create ECR repository
aws ecr create-repository \
    --repository-name healthcare-payment-tracker \
    --region us-east-1

# Get login token and login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
```

### Step 2: Build and Push Docker Image

```bash
# Tag your image for ECR
docker build -t healthcare-payment-tracker .
docker tag healthcare-payment-tracker:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/healthcare-payment-tracker:latest

# Push to ECR
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/healthcare-payment-tracker:latest
```

### Step 3: Create ECS Task Definition

Create `ecs-task-definition.json`:

```json
{
  "family": "healthcare-payment-tracker",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::<account-id>:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "healthcare-app",
      "image": "<account-id>.dkr.ecr.us-east-1.amazonaws.com/healthcare-payment-tracker:latest",
      "portMappings": [
        {
          "containerPort": 80,
          "protocol": "tcp"
        }
      ],
      "essential": true,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/healthcare-payment-tracker",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
```

### Step 4: Create ECS Cluster and Service

```bash
# Create ECS cluster
aws ecs create-cluster --cluster-name healthcare-cluster

# Create CloudWatch log group
aws logs create-log-group --log-group-name /ecs/healthcare-payment-tracker

# Register task definition
aws ecs register-task-definition --cli-input-json file://ecs-task-definition.json

# Create ECS service (requires VPC and security groups)
aws ecs create-service \
    --cluster healthcare-cluster \
    --service-name healthcare-service \
    --task-definition healthcare-payment-tracker:1 \
    --desired-count 2 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[subnet-12345,subnet-67890],securityGroups=[sg-12345],assignPublicIp=ENABLED}" \
    --load-balancers "targetGroupArn=arn:aws:elasticloadbalancing:us-east-1:<account-id>:targetgroup/healthcare-tg/1234567890,containerName=healthcare-app,containerPort=80"
```

### Step 5: Create Application Load Balancer

```bash
# Create ALB
aws elbv2 create-load-balancer \
    --name healthcare-alb \
    --subnets subnet-12345 subnet-67890 \
    --security-groups sg-12345

# Create target group
aws elbv2 create-target-group \
    --name healthcare-tg \
    --protocol HTTP \
    --port 80 \
    --vpc-id vpc-12345 \
    --target-type ip \
    --health-check-path /health

# Create listener
aws elbv2 create-listener \
    --load-balancer-arn arn:aws:elasticloadbalancing:us-east-1:<account-id>:loadbalancer/app/healthcare-alb/1234567890 \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=arn:aws:elasticloadbalancing:us-east-1:<account-id>:targetgroup/healthcare-tg/1234567890
```

## 🖥️ Option 2: EC2 with Docker

### Step 1: Launch EC2 Instance

```bash
# Launch EC2 instance with Docker pre-installed
aws ec2 run-instances \
    --image-id ami-0c02fb55956c7d316 \
    --count 1 \
    --instance-type t3.micro \
    --key-name your-key-pair \
    --security-group-ids sg-12345 \
    --user-data file://user-data.sh
```

Create `user-data.sh`:
```bash
#!/bin/bash
yum update -y
yum install -y docker
service docker start
usermod -a -G docker ec2-user

# Install docker-compose
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Clone your application (replace with your repository)
cd /home/ec2-user
git clone https://github.com/your-username/healthcare-payment-app.git
cd healthcare-payment-app

# Start the application
docker-compose up -d
```

### Step 2: Configure Security Group

```bash
# Allow HTTP traffic
aws ec2 authorize-security-group-ingress \
    --group-id sg-12345 \
    --protocol tcp \
    --port 8080 \
    --cidr 0.0.0.0/0

# Allow SSH access
aws ec2 authorize-security-group-ingress \
    --group-id sg-12345 \
    --protocol tcp \
    --port 22 \
    --cidr your.ip.address/32
```

## ☁️ Option 3: S3 Static Hosting with CloudFront

### Step 1: Create S3 Bucket

```bash
# Create S3 bucket
aws s3 mb s3://healthcare-payment-tracker-static --region us-east-1

# Enable static website hosting
aws s3 website s3://healthcare-payment-tracker-static \
    --index-document index.html \
    --error-document index.html
```

### Step 2: Upload Files

```bash
# Upload application files
aws s3 sync . s3://healthcare-payment-tracker-static \
    --exclude "*.md" \
    --exclude "Dockerfile*" \
    --exclude "docker-compose.yml" \
    --exclude ".git/*" \
    --exclude "nginx.conf"

# Set public read permissions
aws s3 cp s3://healthcare-payment-tracker-static s3://healthcare-payment-tracker-static \
    --recursive \
    --acl public-read
```

### Step 3: Create CloudFront Distribution

Create `cloudfront-config.json`:
```json
{
    "CallerReference": "healthcare-app-2024",
    "DefaultRootObject": "index.html",
    "Origins": {
        "Quantity": 1,
        "Items": [
            {
                "Id": "S3-healthcare-payment-tracker-static",
                "DomainName": "healthcare-payment-tracker-static.s3-website-us-east-1.amazonaws.com",
                "CustomOriginConfig": {
                    "HTTPPort": 80,
                    "HTTPSPort": 443,
                    "OriginProtocolPolicy": "http-only"
                }
            }
        ]
    },
    "DefaultCacheBehavior": {
        "TargetOriginId": "S3-healthcare-payment-tracker-static",
        "ViewerProtocolPolicy": "redirect-to-https",
        "TrustedSigners": {
            "Enabled": false,
            "Quantity": 0
        },
        "ForwardedValues": {
            "QueryString": false,
            "Cookies": {"Forward": "none"}
        },
        "MinTTL": 0
    },
    "Comment": "Healthcare Payment Tracker CDN",
    "Enabled": true
}
```

```bash
# Create CloudFront distribution
aws cloudfront create-distribution --distribution-config file://cloudfront-config.json
```

## 🚀 Option 4: AWS App Runner

### Step 1: Create apprunner.yaml

```yaml
version: 1.0
runtime: docker
build:
  commands:
    build:
      - echo "Build started on `date`"
      - docker build -t healthcare-payment-tracker .
run:
  runtime-version: latest
  command: nginx -g daemon off;
  network:
    port: 80
    env: PORT
  env:
    - name: NODE_ENV
      value: production
```

### Step 2: Deploy to App Runner

```bash
# Create App Runner service
aws apprunner create-service \
    --service-name healthcare-payment-tracker \
    --source-configuration '{
        "ImageRepository": {
            "ImageIdentifier": "<account-id>.dkr.ecr.us-east-1.amazonaws.com/healthcare-payment-tracker:latest",
            "ImageConfiguration": {
                "Port": "80"
            },
            "ImageRepositoryType": "ECR"
        },
        "AutoDeploymentsEnabled": true
    }' \
    --instance-configuration '{
        "Cpu": "0.25 vCPU",
        "Memory": "0.5 GB"
    }'
```

## 💰 Cost Optimization

### ECS Fargate Cost Optimization
```bash
# Use Spot instances for development
aws ecs put-cluster-capacity-providers \
    --cluster healthcare-cluster \
    --capacity-providers FARGATE_SPOT \
    --default-capacity-provider-strategy capacityProvider=FARGATE_SPOT,weight=1
```

### Estimated Monthly Costs
- **ECS Fargate (t3.micro equivalent)**: ~$15-30
- **EC2 t3.micro**: ~$8-12 + data transfer
- **S3 + CloudFront**: ~$1-5 (depending on traffic)
- **App Runner**: ~$20-40

### Cost Monitoring
```bash
# Set up billing alerts
aws budgets create-budget \
    --account-id <account-id> \
    --budget '{
        "BudgetName": "Healthcare-App-Budget",
        "BudgetLimit": {
            "Amount": "50",
            "Unit": "USD"
        },
        "TimeUnit": "MONTHLY",
        "BudgetType": "COST"
    }'
```

## 📊 Monitoring and Logging

### CloudWatch Dashboard
```bash
# Create CloudWatch dashboard
aws cloudwatch put-dashboard \
    --dashboard-name "Healthcare-App-Dashboard" \
    --dashboard-body '{
        "widgets": [
            {
                "type": "metric",
                "properties": {
                    "metrics": [
                        ["AWS/ECS", "CPUUtilization", "ServiceName", "healthcare-service"],
                        ["AWS/ECS", "MemoryUtilization", "ServiceName", "healthcare-service"]
                    ],
                    "period": 300,
                    "stat": "Average",
                    "region": "us-east-1",
                    "title": "ECS Service Metrics"
                }
            }
        ]
    }'
```

### Application Logs
```bash
# View ECS logs
aws logs describe-log-streams --log-group-name /ecs/healthcare-payment-tracker
aws logs get-log-events --log-group-name /ecs/healthcare-payment-tracker --log-stream-name <stream-name>
```

## 🔒 Security Considerations

### Security Groups
```bash
# Create restrictive security group
aws ec2 create-security-group \
    --group-name healthcare-app-sg \
    --description "Security group for Healthcare Payment Tracker"

# Allow only HTTPS traffic
aws ec2 authorize-security-group-ingress \
    --group-id sg-12345 \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0
```

### WAF Configuration
```bash
# Create WAF for additional security
aws wafv2 create-web-acl \
    --name healthcare-app-waf \
    --scope CLOUDFRONT \
    --default-action Allow={} \
    --rules '[
        {
            "Name": "RateLimitRule",
            "Priority": 1,
            "Action": {
                "Block": {}
            },
            "Statement": {
                "RateBasedStatement": {
                    "Limit": 1000,
                    "AggregateKeyType": "IP"
                }
            },
            "VisibilityConfig": {
                "SampledRequestsEnabled": true,
                "CloudWatchMetricsEnabled": true,
                "MetricName": "RateLimitRule"
            }
        }
    ]'
```

### HTTPS/SSL Certificate
```bash
# Request SSL certificate via ACM
aws acm request-certificate \
    --domain-name healthcare.yourdomain.com \
    --validation-method DNS \
    --region us-east-1
```

## 🔧 Environment Variables and Configuration

### ECS Environment Variables
```json
{
  "environment": [
    {
      "name": "NODE_ENV",
      "value": "production"
    },
    {
      "name": "AWS_REGION",
      "value": "us-east-1"
    }
  ]
}
```

## 🚨 Troubleshooting

### Common Issues

1. **ECS Task Failing to Start**
   ```bash
   # Check task definition
   aws ecs describe-tasks --cluster healthcare-cluster --tasks <task-arn>
   
   # Check service events
   aws ecs describe-services --cluster healthcare-cluster --services healthcare-service
   ```

2. **Load Balancer Health Check Failing**
   ```bash
   # Verify target group health
   aws elbv2 describe-target-health --target-group-arn <target-group-arn>
   ```

3. **High Costs**
   ```bash
   # Check cost explorer
   aws ce get-cost-and-usage \
       --time-period Start=2024-01-01,End=2024-01-31 \
       --granularity MONTHLY \
       --metrics BlendedCost
   ```

### Log Analysis
```bash
# Search logs for errors
aws logs filter-log-events \
    --log-group-name /ecs/healthcare-payment-tracker \
    --filter-pattern "ERROR" \
    --start-time 1640995200000
```

## 🔄 CI/CD Pipeline

### GitHub Actions Example
Create `.github/workflows/deploy.yml`:
```yaml
name: Deploy to AWS ECS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v1
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-east-1

    - name: Login to Amazon ECR
      id: login-ecr
      uses: aws-actions/amazon-ecr-login@v1

    - name: Build, tag, and push image to Amazon ECR
      env:
        ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
        ECR_REPOSITORY: healthcare-payment-tracker
        IMAGE_TAG: ${{ github.sha }}
      run: |
        docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
        docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG

    - name: Deploy to Amazon ECS
      uses: aws-actions/amazon-ecs-deploy-task-definition@v1
      with:
        task-definition: ecs-task-definition.json
        service: healthcare-service
        cluster: healthcare-cluster
```

## 📝 Next Steps

After deployment:

1. **Set up monitoring alerts**
2. **Configure automated backups**
3. **Implement blue/green deployments**
4. **Set up custom domain with Route 53**
5. **Enable AWS WAF for additional security**
6. **Configure auto-scaling policies**

## 📞 Support

For issues specific to AWS deployment:
- Check AWS CloudWatch logs
- Review AWS documentation
- Contact AWS support if needed

For application-specific issues:
- Check application logs in CloudWatch
- Review container health checks
- Verify environment variables

---

**Important**: This application handles healthcare payment data. Ensure compliance with HIPAA and other healthcare regulations when deploying to production environments.