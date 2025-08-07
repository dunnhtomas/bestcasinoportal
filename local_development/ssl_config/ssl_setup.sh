#!/bin/bash
set -euo pipefail

# SSL Setup Script for BestCasinoPortal.com
# Professional deployment with error handling and logging

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DOMAIN="bestcasinoportal.com"
EMAIL="admin@bestcasinoportal.com"
LOG_FILE="/var/log/ssl_setup.log"

log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${GREEN}${message}${NC}"
    echo "${message}" >> "$LOG_FILE"
}

error() {
    local message="[ERROR] $1"
    echo -e "${RED}${message}${NC}" >&2
    echo "${message}" >> "$LOG_FILE"
}

warning() {
    local message="[WARNING] $1"
    echo -e "${YELLOW}${message}${NC}"
    echo "${message}" >> "$LOG_FILE"
}

info() {
    local message="[INFO] $1"
    echo -e "${BLUE}${message}${NC}"
    echo "${message}" >> "$LOG_FILE"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
}

# Install Certbot if not present
install_certbot() {
    log "Installing Certbot..."
    
    if ! command -v certbot &> /dev/null; then
        apt update
        apt install -y certbot python3-certbot-nginx
        log "Certbot installed successfully"
    else
        log "Certbot already installed"
    fi
}

# Backup existing SSL certificates
backup_ssl() {
    if [[ -d "/etc/letsencrypt/live/$DOMAIN" ]]; then
        log "Backing up existing SSL certificates..."
        cp -r "/etc/letsencrypt/live/$DOMAIN" "/etc/letsencrypt/live/${DOMAIN}_backup_$(date +%Y%m%d_%H%M%S)"
        log "SSL certificates backed up"
    fi
}

# Obtain SSL certificate
obtain_ssl() {
    log "Obtaining SSL certificate for $DOMAIN..."
    
    # Stop Nginx temporarily to allow Certbot standalone mode
    systemctl stop nginx || true
    
    # Obtain certificate using standalone mode
    if certbot certonly \
        --standalone \
        --non-interactive \
        --agree-tos \
        --email "$EMAIL" \
        -d "$DOMAIN" \
        -d "www.$DOMAIN" \
        --expand; then
        log "SSL certificate obtained successfully"
    else
        error "Failed to obtain SSL certificate"
        systemctl start nginx || true
        exit 1
    fi
    
    # Start Nginx again
    systemctl start nginx
}

# Configure SSL in Nginx
configure_nginx_ssl() {
    log "Configuring Nginx for SSL..."
    
    # Test Nginx configuration
    if nginx -t; then
        log "Nginx configuration is valid"
        systemctl reload nginx
        log "Nginx reloaded with SSL configuration"
    else
        error "Nginx configuration is invalid"
        exit 1
    fi
}

# Setup SSL auto-renewal
setup_auto_renewal() {
    log "Setting up SSL auto-renewal..."
    
    # Add cron job for auto-renewal if not exists
    if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
        (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet && systemctl reload nginx") | crontab -
        log "SSL auto-renewal configured"
    else
        log "SSL auto-renewal already configured"
    fi
}

# Verify SSL installation
verify_ssl() {
    log "Verifying SSL installation..."
    
    # Check certificate files exist
    if [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" && -f "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]]; then
        log "✓ SSL certificate files exist"
    else
        error "✗ SSL certificate files not found"
        exit 1
    fi
    
    # Check certificate validity
    if openssl x509 -in "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" -text -noout | grep -q "bestcasinoportal.com"; then
        log "✓ SSL certificate is valid for $DOMAIN"
    else
        error "✗ SSL certificate is not valid"
        exit 1
    fi
    
    # Test HTTPS connection
    sleep 5  # Give Nginx time to reload
    if curl -f -s "https://$DOMAIN" > /dev/null; then
        log "✓ HTTPS connection successful"
    else
        warning "⚠ HTTPS connection test failed - may need DNS propagation time"
    fi
}

# Main function
main() {
    log "Starting SSL setup for $DOMAIN..."
    
    check_root
    install_certbot
    backup_ssl
    obtain_ssl
    configure_nginx_ssl
    setup_auto_renewal
    verify_ssl
    
    log "🎉 SSL setup completed successfully!"
    log "Certificate location: /etc/letsencrypt/live/$DOMAIN/"
    log "Auto-renewal configured via cron"
    info "Please verify HTTPS is working: https://$DOMAIN"
}

# Run main function
main "$@"
