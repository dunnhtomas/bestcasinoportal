#!/bin/bash
set -euo pipefail

# Best Casino Portal - Clean Server Deployment Script
# MCP-Style Deployment with Full Context Management

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVER_IP="193.233.161.161"
DOMAIN="bestcasinoportal.com"
CLOUDFLARE_TOKEN="pe2L5nDoK0kKvpGVkRSm4P48FExlWfbTZdOZfhXF"
EMAIL="admin@bestcasinoportal.com"
WEB_ROOT="/var/www/bestcasinoportal.com"
NGINX_CONF="/etc/nginx/sites-available/bestcasinoportal.com"

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
}

# Function to update system packages
update_system() {
    log "Updating system packages..."
    apt update && apt upgrade -y
    apt install -y curl wget gnupg2 software-properties-common ufw fail2ban
}

# Function to configure firewall
setup_firewall() {
    log "Configuring UFW firewall..."
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 'Nginx Full'
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw --force enable
    systemctl enable fail2ban
    systemctl start fail2ban
}

# Function to install and configure Nginx
setup_nginx() {
    log "Installing and configuring Nginx..."
    apt install -y nginx
    
    # Remove default configuration
    rm -f /etc/nginx/sites-enabled/default
    rm -f /etc/nginx/sites-available/default
    
    # Create web directory
    mkdir -p $WEB_ROOT
    chown -R www-data:www-data $WEB_ROOT
    chmod -R 755 $WEB_ROOT
    
    # Enable site
    ln -sf $NGINX_CONF /etc/nginx/sites-enabled/
    
    # Test and reload Nginx
    nginx -t
    systemctl enable nginx
    systemctl restart nginx
}

# Function to install Certbot and obtain SSL certificate
setup_ssl() {
    log "Installing Certbot and obtaining SSL certificate..."
    apt install -y certbot python3-certbot-nginx
    
    # Stop nginx temporarily for standalone certificate
    systemctl stop nginx
    
    # Obtain certificate
    certbot certonly --standalone --non-interactive --agree-tos --email $EMAIL -d $DOMAIN -d www.$DOMAIN
    
    # Start nginx again
    systemctl start nginx
    
    # Test and reload with SSL
    nginx -t
    systemctl reload nginx
    
    # Setup auto-renewal
    (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet && systemctl reload nginx") | crontab -
}

# Function to configure Cloudflare DNS via API
setup_cloudflare() {
    log "Configuring Cloudflare DNS..."
    
    # Get zone ID
    ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" \
        -H "Authorization: Bearer $CLOUDFLARE_TOKEN" \
        -H "Content-Type: application/json" | \
        jq -r '.result[0].id')
    
    if [[ "$ZONE_ID" == "null" ]]; then
        error "Could not get Cloudflare zone ID for $DOMAIN"
        return 1
    fi
    
    info "Zone ID: $ZONE_ID"
    
    # Create/Update A record for main domain
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
        -H "Authorization: Bearer $CLOUDFLARE_TOKEN" \
        -H "Content-Type: application/json" \
        --data '{
            "type": "A",
            "name": "'$DOMAIN'",
            "content": "'$SERVER_IP'",
            "ttl": 300,
            "proxied": true
        }' | jq '.'
    
    # Create/Update A record for www subdomain
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
        -H "Authorization: Bearer $CLOUDFLARE_TOKEN" \
        -H "Content-Type: application/json" \
        --data '{
            "type": "A",
            "name": "www.'$DOMAIN'",
            "content": "'$SERVER_IP'",
            "ttl": 300,
            "proxied": true
        }' | jq '.'
    
    # Enable Full SSL (Strict)
    curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/settings/ssl" \
        -H "Authorization: Bearer $CLOUDFLARE_TOKEN" \
        -H "Content-Type: application/json" \
        --data '{"value": "full"}' | jq '.'
    
    # Enable Always Use HTTPS
    curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/settings/always_use_https" \
        -H "Authorization: Bearer $CLOUDFLARE_TOKEN" \
        -H "Content-Type: application/json" \
        --data '{"value": "on"}' | jq '.'
    
    log "Cloudflare DNS configured successfully"
}

# Function to setup monitoring
setup_monitoring() {
    log "Setting up basic monitoring..."
    
    # Install monitoring tools
    apt install -y htop iotop netstat-ss logrotate
    
    # Setup log rotation for nginx
    cat > /etc/logrotate.d/nginx << 'EOF'
/var/log/nginx/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 nginx nginx
    postrotate
        if [ -f /var/run/nginx.pid ]; then
            kill -USR1 cat /var/run/nginx.pid
        fi
    endscript
}
EOF
}

# Function to create health check endpoint
setup_health_check() {
    log "Setting up health check endpoint..."
    
    cat > $WEB_ROOT/health << 'EOF'
{
    "status": "healthy",
    "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)'",
    "version": "1.0.0",
    "services": {
        "nginx": "running",
        "ssl": "active"
    }
}
EOF
    
    chown www-data:www-data $WEB_ROOT/health
    chmod 644 $WEB_ROOT/health
}

# Function to optimize server performance
optimize_server() {
    log "Optimizing server performance..."
    
    # Optimize Nginx worker processes
    CORES=$(nproc)
    sed -i "s/worker_processes.*/worker_processes $CORES;/" /etc/nginx/nginx.conf
    
    # Increase file descriptor limits
    echo "* soft nofile 65535" >> /etc/security/limits.conf
    echo "* hard nofile 65535" >> /etc/security/limits.conf
    
    # Optimize kernel parameters
    cat >> /etc/sysctl.conf << 'EOF'
# Network optimizations
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 65536 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
EOF
    
    sysctl -p
}

# Function to setup backup system
setup_backup() {
    log "Setting up backup system..."
    
    mkdir -p /root/backups
    
    cat > /root/backup_website.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/root/backups"
DATE=$(date +%Y%m%d_%H%M%S)
tar -czf $BACKUP_DIR/website_$DATE.tar.gz -C /var/www/ bestcasinoportal.com/
tar -czf $BACKUP_DIR/nginx_$DATE.tar.gz -C /etc/ nginx/
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
EOF
    
    chmod +x /root/backup_website.sh
    
    # Add to crontab
    (crontab -l 2>/dev/null; echo "0 2 * * * /root/backup_website.sh") | crontab -
}

# Function to verify deployment
verify_deployment() {
    log "Verifying deployment..."
    
    # Check Nginx status
    if systemctl is-active --quiet nginx; then
        log "✓ Nginx is running"
    else
        error "✗ Nginx is not running"
        return 1
    fi
    
    # Check website accessibility
    if curl -f -s http://localhost/ > /dev/null; then
        log "✓ Website is accessible via HTTP"
    else
        error "✗ Website is not accessible via HTTP"
        return 1
    fi
    
    # Check SSL certificate
    if [[ -f /etc/letsencrypt/live/$DOMAIN/fullchain.pem ]]; then
        log "✓ SSL certificate exists"
    else
        warning "⚠ SSL certificate not found"
    fi
    
    # Check firewall status
    if ufw status | grep -q "Status: active"; then
        log "✓ Firewall is active"
    else
        warning "⚠ Firewall is not active"
    fi
    
    log "Deployment verification completed"
}

# Main deployment function
main() {
    log "Starting Best Casino Portal deployment..."
    
    check_root
    update_system
    setup_firewall
    setup_nginx
    setup_ssl
    setup_cloudflare
    setup_monitoring
    setup_health_check
    optimize_server
    setup_backup
    verify_deployment
    
    log "🎉 Deployment completed successfully!"
    log "Website URL: https://$DOMAIN"
    log "Health Check: https://$DOMAIN/health"
    info "Please verify the website is accessible and SSL is working properly."
}

# Run main function
main "$@"
