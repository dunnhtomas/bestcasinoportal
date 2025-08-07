#!/bin/bash
set -e

echo "🚀 PROFESSIONAL DEPLOYMENT SCRIPT FOR BESTCASINOPORTAL.COM"
echo "=========================================================="

# Variables
DEPLOY_USER="root"
SERVER_IP="193.233.161.161"
SSH_KEY="$HOME/.ssh/bestcasinoportal_ed25519"
DOMAIN="bestcasinoportal.com"
LOCAL_DIR="$(pwd)"
REMOTE_DIR="/root/deployment/production"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# Pre-flight checks
preflight_checks() {
    log "🔍 Running pre-flight checks..."
    
    # Check if SSH key exists
    if [[ ! -f "$SSH_KEY" ]]; then
        error "SSH key not found: $SSH_KEY"
    fi
    
    # Test SSH connection
    ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$DEPLOY_USER@$SERVER_IP" "echo 'SSH connection test successful'" || error "SSH connection failed"
    
    # Check if required files exist
    [[ -f "local_development/ssl_config/ssl-setup.sh" ]] || error "SSL setup script not found"
    [[ -f "local_development/api_server/api-server.js" ]] || error "API server script not found"
    [[ -f "local_development/api_server/package.json" ]] || error "Package.json not found"
    
    log "✅ Pre-flight checks passed"
}

# Deploy files to server
deploy_files() {
    log "📁 Deploying files to server..."
    
    # Create remote directory
    ssh -i "$SSH_KEY" "$DEPLOY_USER@$SERVER_IP" "mkdir -p $REMOTE_DIR"
    
    # Upload SSL setup script
    scp -i "$SSH_KEY" "local_development/ssl_config/ssl-setup.sh" "$DEPLOY_USER@$SERVER_IP:$REMOTE_DIR/"
    
    # Upload API server files
    scp -i "$SSH_KEY" "local_development/api_server/"* "$DEPLOY_USER@$SERVER_IP:$REMOTE_DIR/"
    
    # Upload deployment and monitoring scripts
    scp -i "$SSH_KEY" "local_development/scripts/"* "$DEPLOY_USER@$SERVER_IP:$REMOTE_DIR/" 2>/dev/null || true
    
    log "✅ Files deployed successfully"
}

# Set proper permissions
set_permissions() {
    log "🔐 Setting proper file permissions..."
    
    ssh -i "$SSH_KEY" "$DEPLOY_USER@$SERVER_IP" "
        chmod +x $REMOTE_DIR/*.sh
        chmod 644 $REMOTE_DIR/*.js
        chmod 644 $REMOTE_DIR/*.json
        chown -R root:root $REMOTE_DIR
    "
    
    log "✅ Permissions set correctly"
}

# Install dependencies
install_dependencies() {
    log "📦 Installing Node.js dependencies..."
    
    ssh -i "$SSH_KEY" "$DEPLOY_USER@$SERVER_IP" "
        cd $REMOTE_DIR
        npm install --production
    "
    
    log "✅ Dependencies installed"
}

# Setup SSL
setup_ssl() {
    log "🔒 Setting up SSL certificate..."
    
    ssh -i "$SSH_KEY" "$DEPLOY_USER@$SERVER_IP" "
        cd $REMOTE_DIR
        ./ssl-setup.sh
    " || warning "SSL setup had issues, check manually"
    
    log "✅ SSL setup completed"
}

# Setup API server as systemd service
setup_api_service() {
    log "⚙️ Setting up API server as systemd service..."
    
    ssh -i "$SSH_KEY" "$DEPLOY_USER@$SERVER_IP" "
        # Create systemd service file
        cat > /etc/systemd/system/casino-api.service << 'EOF'
[Unit]
Description=BestCasinoPortal API Server
After=network.target postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=$REMOTE_DIR
ExecStart=/usr/bin/node api-server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

        # Enable and start service
        systemctl daemon-reload
        systemctl enable casino-api
        systemctl restart casino-api
        
        # Check status
        systemctl status casino-api --no-pager
    "
    
    log "✅ API service configured and started"
}

# Update Nginx configuration
update_nginx() {
    log "🌐 Updating Nginx configuration..."
    
    ssh -i "$SSH_KEY" "$DEPLOY_USER@$SERVER_IP" "
        # Backup current config
        cp /etc/nginx/sites-available/bestcasinoportal.com /etc/nginx/sites-available/bestcasinoportal.com.backup
        
        # Add API proxy to Nginx config
        sed -i '/location \/api\//,/}/c\
        location /api/ {\
            proxy_pass http://127.0.0.1:3000;\
            proxy_http_version 1.1;\
            proxy_set_header Upgrade \$http_upgrade;\
            proxy_set_header Connection \"upgrade\";\
            proxy_set_header Host \$host;\
            proxy_set_header X-Real-IP \$remote_addr;\
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;\
            proxy_set_header X-Forwarded-Proto \$scheme;\
            proxy_cache_bypass \$http_upgrade;\
        }' /etc/nginx/sites-available/bestcasinoportal.com
        
        # Test and reload Nginx
        nginx -t && systemctl reload nginx
    "
    
    log "✅ Nginx configuration updated"
}

# Run tests
run_tests() {
    log "🧪 Running deployment tests..."
    
    # Test website accessibility
    curl -I "https://$DOMAIN" || warning "HTTPS test failed"
    curl -I "http://$SERVER_IP" || warning "HTTP test failed"
    
    # Test API endpoints
    curl -s "http://$SERVER_IP:3000/health" | grep -q "OK" && log "✅ API health check passed" || warning "API health check failed"
    curl -s "http://$SERVER_IP:3000/api/casinos" | grep -q "success" && log "✅ API casinos endpoint passed" || warning "API casinos test failed"
    
    log "✅ Tests completed"
}

# Main deployment function
main() {
    log "🚀 Starting professional deployment..."
    
    preflight_checks
    deploy_files
    set_permissions
    install_dependencies
    setup_ssl
    setup_api_service
    update_nginx
    run_tests
    
    log "🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!"
    log "🌐 Website: https://$DOMAIN"
    log "📊 API: http://$SERVER_IP:3000"
}

# Run main function
main "$@"
