#!/bin/bash

# Healthcare Payment Tracker - HTTPS Setup Script
# This script sets up Traefik with Let's Encrypt for secure HTTPS connections

set -e  # Exit on error

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

# Configuration
DOMAIN="nomi.payment.ats-victorycenter.org"
EMAIL="admin@ats-victorycenter.org"  # Change this to your email

log_info "Setting up HTTPS for Healthcare Payment Tracker"
log_info "Domain: $DOMAIN"
log_info "Email: $EMAIL"

# Step 1: Create acme.json file with proper permissions
log_info "Creating acme.json file for Let's Encrypt certificates..."
touch acme.json
chmod 600 acme.json

# Step 2: Create Traefik network
log_info "Creating Traefik Docker network..."
if ! docker network ls | grep -q "traefik"; then
    docker network create traefik
    log_success "Created traefik network"
else
    log_info "Traefik network already exists"
fi

# Step 3: Stop any existing containers
log_info "Stopping existing containers..."
docker compose down 2>/dev/null || true

# Step 4: Update email in traefik.yml
log_info "Updating email in traefik.yml..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/admin@ats-victorycenter.org/$EMAIL/g" traefik.yml
else
    # Linux
    sed -i "s/admin@ats-victorycenter.org/$EMAIL/g" traefik.yml
fi

# Step 5: Verify DNS resolution
log_info "Verifying DNS resolution for $DOMAIN..."
if nslookup $DOMAIN > /dev/null 2>&1; then
    RESOLVED_IP=$(nslookup $DOMAIN | grep "Address:" | tail -n1 | cut -d' ' -f2)
    PUBLIC_IP=$(curl -s http://checkip.amazonaws.com/ || curl -s http://ifconfig.me/)
    
    log_info "Domain resolves to: $RESOLVED_IP"
    log_info "Server public IP: $PUBLIC_IP"
    
    if [ "$RESOLVED_IP" != "$PUBLIC_IP" ]; then
        log_warning "DNS resolution mismatch! Make sure $DOMAIN points to $PUBLIC_IP"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_error "Exiting. Please fix DNS resolution first."
            exit 1
        fi
    else
        log_success "DNS resolution verified"
    fi
else
    log_error "Cannot resolve $DOMAIN. Please check your DNS settings."
    exit 1
fi

# Step 6: Check firewall ports
log_info "Checking firewall configuration..."
if command -v ufw >/dev/null 2>&1; then
    log_info "Checking UFW firewall..."
    if ufw status | grep -q "80/tcp"; then
        log_info "Port 80 is open"
    else
        log_warning "Opening port 80..."
        sudo ufw allow 80/tcp
    fi
    
    if ufw status | grep -q "443/tcp"; then
        log_info "Port 443 is open"
    else
        log_warning "Opening port 443..."
        sudo ufw allow 443/tcp
    fi
fi

# Step 7: Start services
log_info "Starting Traefik and Healthcare app..."
docker compose up -d --build

# Step 8: Wait for services to start
log_info "Waiting for services to start..."
sleep 30

# Step 9: Check service status
log_info "Checking service status..."
if docker ps | grep -q traefik; then
    log_success "Traefik is running"
else
    log_error "Traefik failed to start"
    docker compose logs traefik
    exit 1
fi

if docker ps | grep -q healthcare-payment-tracker; then
    log_success "Healthcare app is running"
else
    log_error "Healthcare app failed to start"
    docker compose logs healthcare-app
    exit 1
fi

# Step 10: Test HTTP to HTTPS redirect
log_info "Testing HTTP to HTTPS redirect..."
sleep 10
HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -L http://$DOMAIN || echo "000")
if [ "$HTTP_RESPONSE" = "200" ]; then
    log_success "HTTP redirect is working"
else
    log_warning "HTTP response: $HTTP_RESPONSE (may take a few minutes for SSL certificate)"
fi

# Step 11: Test HTTPS
log_info "Testing HTTPS connection..."
sleep 20
HTTPS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -k https://$DOMAIN || echo "000")
if [ "$HTTPS_RESPONSE" = "200" ]; then
    log_success "HTTPS is working!"
else
    log_warning "HTTPS response: $HTTPS_RESPONSE (SSL certificate may still be generating)"
fi

# Step 12: Display status and URLs
log_success "Setup completed!"
echo ""
log_info "📋 Service URLs:"
log_info "🌐 Healthcare App: https://$DOMAIN"
log_info "📊 Traefik Dashboard: https://traefik.$DOMAIN (user: admin, pass: admin)"
echo ""
log_info "📝 Important Notes:"
log_info "• SSL certificate generation may take 1-5 minutes"
log_info "• Check logs with: docker compose logs -f"
log_info "• Certificate stored in: ./acme.json"
log_info "• Automatic renewal enabled"
echo ""

# Step 13: Show logs
log_info "Recent logs:"
docker compose logs --tail=20

# Step 14: Certificate monitoring
log_info "Setting up certificate monitoring..."
cat > check_cert.sh << 'EOF'
#!/bin/bash
# Certificate monitoring script
DOMAIN="nomi.payment.ats-victorycenter.org"
EXPIRY_DAYS=$(curl -s https://$DOMAIN 2>/dev/null | openssl x509 -noout -dates 2>/dev/null | grep notAfter | cut -d= -f2)
if [ ! -z "$EXPIRY_DAYS" ]; then
    echo "Certificate expires: $EXPIRY_DAYS"
else
    echo "Could not check certificate expiry"
fi
EOF
chmod +x check_cert.sh

log_success "HTTPS setup completed! Your app should be available at https://$DOMAIN"
log_info "Run './check_cert.sh' to check certificate status"