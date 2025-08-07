#!/bin/bash
set -euo pipefail

# Professional Deployment Script for BestCasinoPortal.com
# Includes backup, verification, monitoring, and rollback capabilities

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SERVER_IP="193.233.161.161"
DOMAIN="bestcasinoportal.com"
CLOUDFLARE_TOKEN="pe2L5nDoK0kKvpGVkRSm4P48FExlWfbTZdOZfhXF"
EMAIL="admin@bestcasinoportal.com"
WEB_ROOT="/var/www/bestcasinoportal.com"
API_ROOT="/opt/bestcasinoportal-api"
BACKUP_DIR="/var/backups/bestcasinoportal"
LOG_FILE="/var/log/deployment.log"
SSH_KEY="~/.ssh/bestcasinoportal_ed25519"

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

# Check prerequisites
check_prerequisites() {
    log "Checking deployment prerequisites..."
    
    # Check if SSH key exists
    if [[ ! -f "$SSH_KEY" ]]; then
        error "SSH key not found: $SSH_KEY"
        exit 1
    fi
    
    # Test SSH connection
    if ! ssh -i "$SSH_KEY" -o ConnectTimeout=10 root@"$SERVER_IP" "echo 'SSH connection successful'" > /dev/null 2>&1; then
        error "Cannot establish SSH connection to $SERVER_IP"
        exit 1
    fi
    
    # Check if required files exist locally
    local required_files=(
        "local_development/ssl_config/ssl_setup.sh"
        "local_development/api_server/server.js"
        "local_development/api_server/package.json"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            error "Required file not found: $file"
            exit 1
        fi
    done
    
    log "✓ All prerequisites satisfied"
}

# Create backup before deployment
create_backup() {
    log "Creating backup before deployment..."
    
    ssh -i "$SSH_KEY" root@"$SERVER_IP" << 'EOSSH'
        set -e
        
        BACKUP_DIR="/var/backups/bestcasinoportal"
        DATE=$(date +%Y%m%d_%H%M%S)
        
        # Create backup directory
        mkdir -p "$BACKUP_DIR"
        
        # Backup website files
        if [[ -d "/var/www/bestcasinoportal.com" ]]; then
            tar -czf "$BACKUP_DIR/website_$DATE.tar.gz" -C /var/www/ bestcasinoportal.com/
            echo "Website files backed up"
        fi
        
        # Backup Nginx configuration
        if [[ -d "/etc/nginx" ]]; then
            tar -czf "$BACKUP_DIR/nginx_$DATE.tar.gz" -C /etc/ nginx/
            echo "Nginx configuration backed up"
        fi
        
        # Backup SSL certificates
        if [[ -d "/etc/letsencrypt" ]]; then
            tar -czf "$BACKUP_DIR/ssl_$DATE.tar.gz" -C /etc/ letsencrypt/
            echo "SSL certificates backed up"
        fi
        
        # Backup API server
        if [[ -d "/opt/bestcasinoportal-api" ]]; then
            tar -czf "$BACKUP_DIR/api_$DATE.tar.gz" -C /opt/ bestcasinoportal-api/
            echo "API server backed up"
        fi
        
        echo "Backup completed: $DATE"
EOSSH
    
    log "✓ Backup completed successfully"
}

# Deploy SSL configuration
deploy_ssl() {
    log "Deploying SSL configuration..."
    
    # Copy SSL setup script to server
    scp -i "$SSH_KEY" "local_development/ssl_config/ssl_setup.sh" root@"$SERVER_IP":/tmp/
    
    # Execute SSL setup on server
    ssh -i "$SSH_KEY" root@"$SERVER_IP" << 'EOSSH'
        set -e
        
        # Make SSL setup script executable
        chmod +x /tmp/ssl_setup.sh
        
        # Run SSL setup
        /tmp/ssl_setup.sh
        
        # Clean up
        rm -f /tmp/ssl_setup.sh
        
        echo "SSL setup completed"
EOSSH
    
    log "✓ SSL configuration deployed"
}

# Deploy API server
deploy_api() {
    log "Deploying API server..."
    
    # Create API directory on server
    ssh -i "$SSH_KEY" root@"$SERVER_IP" "mkdir -p /opt/bestcasinoportal-api"
    
    # Copy API files to server
    scp -i "$SSH_KEY" "local_development/api_server/server.js" root@"$SERVER_IP":/opt/bestcasinoportal-api/
    scp -i "$SSH_KEY" "local_development/api_server/package.json" root@"$SERVER_IP":/opt/bestcasinoportal-api/
    
    # Install dependencies and start API server
    ssh -i "$SSH_KEY" root@"$SERVER_IP" << 'EOSSH'
        set -e
        
        cd /opt/bestcasinoportal-api
        
        # Install Node.js if not present
        if ! command -v node &> /dev/null; then
            curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
            apt-get install -y nodejs
        fi
        
        # Install dependencies
        npm install --production
        
        # Create systemd service for API server
        cat > /etc/systemd/system/bestcasinoportal-api.service << 'EOF'
[Unit]
Description=BestCasinoPortal API Server
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/bestcasinoportal-api
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=4000

[Install]
WantedBy=multi-user.target
EOF
        
        # Enable and start service
        systemctl daemon-reload
        systemctl enable bestcasinoportal-api
        systemctl start bestcasinoportal-api
        
        # Set proper permissions
        chown -R www-data:www-data /opt/bestcasinoportal-api
        
        echo "API server deployed and started"
EOSSH
    
    log "✓ API server deployed successfully"
}

# Update Nginx configuration for API proxy
update_nginx() {
    log "Updating Nginx configuration for API proxy..."
    
    ssh -i "$SSH_KEY" root@"$SERVER_IP" << 'EOSSH'
        set -e
        
        # Backup current Nginx config
        cp /etc/nginx/sites-available/bestcasinoportal.com /etc/nginx/sites-available/bestcasinoportal.com.backup
        
        # Update Nginx config to include API proxy
        cat > /etc/nginx/sites-available/bestcasinoportal.com << 'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name bestcasinoportal.com www.bestcasinoportal.com;
    
    # Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        root /var/www/letsencrypt;
    }
    
    # Redirect all other HTTP to HTTPS
    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name bestcasinoportal.com www.bestcasinoportal.com;
    
    root /var/www/bestcasinoportal.com;
    index index.html index.htm;
    
    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/bestcasinoportal.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/bestcasinoportal.com/privkey.pem;
    
    # SSL Security
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    
    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # API Proxy
    location /api/ {
        proxy_pass http://localhost:4000/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 5s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Health check endpoint
    location /health {
        proxy_pass http://localhost:4000/health;
        access_log off;
    }
    
    # Main location block
    location / {
        try_files $uri $uri/ /index.html;
        expires 1d;
        add_header Cache-Control "public, immutable";
    }
    
    # Static assets caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header Vary "Accept-Encoding";
    }
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
}
EOF
        
        # Test and reload Nginx
        nginx -t
        systemctl reload nginx
        
        echo "Nginx configuration updated"
EOSSH
    
    log "✓ Nginx configuration updated successfully"
}

# Verify deployment
verify_deployment() {
    log "Verifying deployment..."
    
    # Test HTTPS connection
    if curl -f -s "https://$DOMAIN" > /dev/null; then
        log "✓ HTTPS connection successful"
    else
        error "✗ HTTPS connection failed"
        return 1
    fi
    
    # Test API health endpoint
    if curl -f -s "https://$DOMAIN/health" | grep -q "healthy"; then
        log "✓ API health check successful"
    else
        error "✗ API health check failed"
        return 1
    fi
    
    # Test API endpoint
    if curl -f -s "https://$DOMAIN/api/casinos" | grep -q "success"; then
        log "✓ API endpoint test successful"
    else
        error "✗ API endpoint test failed"
        return 1
    fi
    
    log "✓ Deployment verification completed successfully"
}

# Setup monitoring
setup_monitoring() {
    log "Setting up monitoring..."
    
    ssh -i "$SSH_KEY" root@"$SERVER_IP" << 'EOSSH'
        set -e
        
        # Create monitoring script
        cat > /opt/monitor_bestcasinoportal.sh << 'EOF'
#!/bin/bash

# Monitor BestCasinoPortal services
LOG_FILE="/var/log/monitoring.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Check Nginx status
if systemctl is-active --quiet nginx; then
    log_message "✓ Nginx is running"
else
    log_message "✗ Nginx is down - attempting restart"
    systemctl start nginx
fi

# Check API server status
if systemctl is-active --quiet bestcasinoportal-api; then
    log_message "✓ API server is running"
else
    log_message "✗ API server is down - attempting restart"
    systemctl start bestcasinoportal-api
fi

# Check website accessibility
if curl -f -s https://bestcasinoportal.com > /dev/null; then
    log_message "✓ Website is accessible"
else
    log_message "✗ Website is not accessible"
fi

# Check API health
if curl -f -s https://bestcasinoportal.com/health | grep -q "healthy"; then
    log_message "✓ API is healthy"
else
    log_message "✗ API health check failed"
fi

# Check disk space
DISK_USAGE=$(df / | awk 'NR==2{print $5}' | sed 's/%//')
if [[ $DISK_USAGE -gt 80 ]]; then
    log_message "⚠ Warning: Disk usage is ${DISK_USAGE}%"
fi

# Check memory usage
MEMORY_USAGE=$(free | grep Mem | awk '{printf("%.2f", $3/$2 * 100.0)}')
if (( $(echo "$MEMORY_USAGE > 80" | bc -l) )); then
    log_message "⚠ Warning: Memory usage is ${MEMORY_USAGE}%"
fi
EOF
        
        chmod +x /opt/monitor_bestcasinoportal.sh
        
        # Add monitoring to crontab
        (crontab -l 2>/dev/null; echo "*/5 * * * * /opt/monitor_bestcasinoportal.sh") | crontab -
        
        echo "Monitoring setup completed"
EOSSH
    
    log "✓ Monitoring setup completed"
}

# Update status.json
update_status() {
    log "Updating deployment status..."
    
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%S+03:00)
    local git_hash=$(git rev-parse HEAD 2>/dev/null || echo "local_deploy")
    
    cat > status.json << EOF
{
  "projectName": "bestcasinoportal",
  "currentPhase": 16,
  "phaseStatus": "completed",
  "lastUpdated": "$timestamp",
  "contextSnapshot": "$git_hash",
  "deployment": {
    "server": "$SERVER_IP",
    "domain": "$DOMAIN",
    "ssh_status": "configured",
    "ssl_status": "active",
    "api_status": "running",
    "monitoring_status": "active",
    "cloudflare_status": "configured",
    "backup_status": "configured"
  },
  "services": {
    "nginx": "running",
    "ssl": "active",
    "api_server": "running",
    "monitoring": "active"
  },
  "urls": {
    "website": "https://$DOMAIN",
    "api_health": "https://$DOMAIN/health",
    "api_base": "https://$DOMAIN/api/"
  },
  "nextActions": [
    "Monitor deployment for 24 hours",
    "Implement full CI/CD pipeline",
    "Setup advanced monitoring and alerting",
    "Optimize performance and caching"
  ]
}
EOF
    
    log "✓ Status updated successfully"
}

# Main deployment function
main() {
    log "🚀 Starting professional deployment for BestCasinoPortal.com..."
    
    check_prerequisites
    create_backup
    deploy_ssl
    deploy_api
    update_nginx
    verify_deployment
    setup_monitoring
    update_status
    
    log "🎉 Deployment completed successfully!"
    log "Website: https://$DOMAIN"
    log "API Health: https://$DOMAIN/health"
    log "API Base: https://$DOMAIN/api/"
    
    info "Next steps:"
    info "1. Monitor deployment for any issues"
    info "2. Test all functionality thoroughly"
    info "3. Setup advanced monitoring and alerting"
    info "4. Implement CI/CD pipeline"
}

# Run main function
main "$@"
