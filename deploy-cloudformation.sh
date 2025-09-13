#!/bin/bash

# Healthcare Payment Tracker - CloudFormation Deployment Script
# This script automates the complete AWS deployment process

set -e  # Exit on any error

# Configuration
STACK_NAME="${1:-healthcare-payment-tracker}"
REGION="${2:-us-east-1}"
ENVIRONMENT="${3:-production}"
DESIRED_COUNT="${4:-2}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install it first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials are not configured. Run 'aws configure' first."
        exit 1
    fi
    
    # Check if CloudFormation template exists
    if [ ! -f "cloudformation-template.yaml" ]; then
        log_error "CloudFormation template not found. Make sure cloudformation-template.yaml exists."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Get AWS account ID
get_account_id() {
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    log_info "AWS Account ID: $ACCOUNT_ID"
}

# Create ECR repository and push image
setup_ecr() {
    log_info "Setting up ECR repository..."
    
    REPO_NAME="${STACK_NAME}-repo"
    ECR_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}"
    
    # Check if repository exists
    if ! aws ecr describe-repositories --repository-names $REPO_NAME --region $REGION &> /dev/null; then
        log_info "Creating ECR repository..."
        aws ecr create-repository \
            --repository-name $REPO_NAME \
            --region $REGION \
            --image-scanning-configuration scanOnPush=true \
            --encryption-configuration encryptionType=AES256
    else
        log_info "ECR repository already exists"
    fi
    
    # Login to ECR
    log_info "Logging in to ECR..."
    aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI
    
    # Build and push image
    log_info "Building Docker image..."
    docker build -t $REPO_NAME:latest .
    docker tag $REPO_NAME:latest $ECR_URI:latest
    
    log_info "Pushing image to ECR..."
    docker push $ECR_URI:latest
    
    log_success "ECR setup completed. Image URI: $ECR_URI:latest"
}

# Deploy CloudFormation stack
deploy_stack() {
    log_info "Deploying CloudFormation stack..."
    
    # Check if stack exists
    if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION &> /dev/null; then
        log_info "Stack exists. Updating..."
        OPERATION="update-stack"
    else
        log_info "Creating new stack..."
        OPERATION="create-stack"
    fi
    
    # Deploy stack
    aws cloudformation $OPERATION \
        --stack-name $STACK_NAME \
        --template-body file://cloudformation-template.yaml \
        --parameters \
            ParameterKey=EnvironmentName,ParameterValue=$ENVIRONMENT \
            ParameterKey=ContainerImage,ParameterValue=$ECR_URI:latest \
            ParameterKey=DesiredCount,ParameterValue=$DESIRED_COUNT \
        --capabilities CAPABILITY_IAM \
        --region $REGION \
        --tags \
            Key=Environment,Value=$ENVIRONMENT \
            Key=Project,Value=HealthcarePaymentTracker \
            Key=ManagedBy,Value=CloudFormation
    
    log_info "Waiting for stack deployment to complete..."
    aws cloudformation wait stack-${OPERATION//-stack/}-complete --stack-name $STACK_NAME --region $REGION
    
    if [ $? -eq 0 ]; then
        log_success "Stack deployment completed successfully"
    else
        log_error "Stack deployment failed"
        exit 1
    fi
}

# Get stack outputs
get_outputs() {
    log_info "Retrieving stack outputs..."
    
    OUTPUTS=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs' \
        --output table)
    
    echo "$OUTPUTS"
    
    # Get load balancer URL
    LB_URL=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerUrl`].OutputValue' \
        --output text)
    
    if [ ! -z "$LB_URL" ]; then
        log_success "Application URL: $LB_URL"
        
        # Test the application
        log_info "Testing application health..."
        sleep 60  # Wait for services to be ready
        
        if curl -f "${LB_URL}/health" &> /dev/null; then
            log_success "Application is healthy and responding"
        else
            log_warning "Application health check failed. It may still be starting up."
        fi
    fi
}

# Setup monitoring
setup_monitoring() {
    log_info "Setting up additional monitoring..."
    
    # Create SNS topic for alerts
    SNS_TOPIC_ARN=$(aws sns create-topic \
        --name "${STACK_NAME}-alerts" \
        --region $REGION \
        --query 'TopicArn' \
        --output text)
    
    log_info "Created SNS topic: $SNS_TOPIC_ARN"
    
    # Subscribe to SNS topic (optional)
    read -p "Enter email for alerts (optional): " EMAIL
    if [ ! -z "$EMAIL" ]; then
        aws sns subscribe \
            --topic-arn $SNS_TOPIC_ARN \
            --protocol email \
            --notification-endpoint $EMAIL \
            --region $REGION
        log_info "Subscribed $EMAIL to alerts. Check your email to confirm subscription."
    fi
    
    # Create additional CloudWatch alarms
    cat > additional-alarms.json << EOF
{
  "AlarmName": "${STACK_NAME}-HighErrorRate",
  "AlarmDescription": "High error rate detected",
  "MetricName": "HTTPCode_Target_5XX_Count",
  "Namespace": "AWS/ApplicationELB",
  "Statistic": "Sum",
  "Period": 300,
  "EvaluationPeriods": 2,
  "Threshold": 10,
  "ComparisonOperator": "GreaterThanThreshold",
  "AlarmActions": ["$SNS_TOPIC_ARN"],
  "Dimensions": [
    {
      "Name": "LoadBalancer",
      "Value": "$(aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query 'Stacks[0].Outputs[?OutputKey==`ApplicationLoadBalancer`].OutputValue' --output text | cut -d'/' -f2-)"
    }
  ]
}
EOF
    
    aws cloudwatch put-metric-alarm --cli-input-json file://additional-alarms.json --region $REGION
    rm additional-alarms.json
    
    log_success "Monitoring setup completed"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up temporary files..."
    rm -f additional-alarms.json
}

# Main deployment function
main() {
    log_info "Starting Healthcare Payment Tracker deployment..."
    log_info "Stack: $STACK_NAME"
    log_info "Region: $REGION"
    log_info "Environment: $ENVIRONMENT"
    log_info "Desired Count: $DESIRED_COUNT"
    
    check_prerequisites
    get_account_id
    setup_ecr
    deploy_stack
    get_outputs
    setup_monitoring
    cleanup
    
    log_success "Deployment completed successfully!"
    log_info "Next steps:"
    log_info "1. Configure your domain name (if needed)"
    log_info "2. Set up SSL certificate via ACM"
    log_info "3. Configure Route 53 for DNS"
    log_info "4. Review CloudWatch dashboards and alarms"
    log_info "5. Test all application features"
}

# Script usage
usage() {
    echo "Usage: $0 [stack-name] [region] [environment] [desired-count]"
    echo ""
    echo "Parameters:"
    echo "  stack-name      Name of the CloudFormation stack (default: healthcare-payment-tracker)"
    echo "  region          AWS region (default: us-east-1)"
    echo "  environment     Environment name (default: production)"
    echo "  desired-count   Number of ECS tasks (default: 2)"
    echo ""
    echo "Example:"
    echo "  $0 my-healthcare-app us-west-2 staging 1"
    exit 1
}

# Handle script arguments
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
fi

# Trap to ensure cleanup runs on script exit
trap cleanup EXIT

# Run main function
main