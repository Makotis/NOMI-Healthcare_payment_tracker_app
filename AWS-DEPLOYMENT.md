# Healthcare Payment Tracker - AWS Deployment Guide

This guide provides comprehensive instructions for deploying the Healthcare Payment Tracker application on Amazon Web Services (AWS) using multiple deployment strategies.

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Deployment Options Overview](#deployment-options-overview)
- [Option 1: ECS Fargate (Recommended)](#option-1-ecs-fargate-recommended)
- [Option 2: EC2 with Docker](#option-2-ec2-with-docker)
- [Option 3: S3 Static Hosting with CloudFront](#option-3-s3-static-hosting-with-cloudfront)
- [Option 4: AWS App Runner](#option-4-aws-app-runner)
- [Cost Optimization](#cost-optimization)
- [Monitoring and Logging](#monitoring-and-logging)
- [Security Considerations](#security-considerations)
- [Troubleshooting](#troubleshooting)

## 🎯 Prerequisites

### Required Tools
- **AWS CLI** installed and configured
- **Docker** installed locally
- **AWS Account** with appropriate permissions
- **Domain name** (optional, for custom domains)

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

| Option | Complexity | Cost | Scalability | Use Case |
|--------|------------|------|-------------|----------|
| **ECS Fargate** | Medium | $15-30/month | High | Production environments |
| **EC2 + Docker** | Medium | $10-20/month | Medium | Development/Testing |
| **S3 + CloudFront** | Low | $2-5/month | High | Static hosting only |
| **App Runner** | Low | $20-40/month | High | Simplest container deployment |

## 🏗️ Option 1: ECS Fargate (Recommended)

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