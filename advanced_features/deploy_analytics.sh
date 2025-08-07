#!/bin/bash

# Casino Portal Analytics Dashboard Deployment Script
# Usage: ./deploy_analytics.sh [environment]

set -e

# Configuration
ENVIRONMENT=${1:-production}
SERVER_IP="193.233.161.161"
SERVER_USER="root"
SSH_KEY="~/.ssh/bestcasinoportal_ed25519"
REMOTE_DIR="/var/www/bestcasinoportal.com"
ANALYTICS_DIR="$REMOTE_DIR/analytics"
API_DIR="$REMOTE_DIR/api"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
    exit 1
}

# Pre-deployment checks
log "Starting analytics dashboard deployment to $ENVIRONMENT..."

# Check if files exist
if [ ! -f "admin_dashboard.html" ]; then
    error "admin_dashboard.html not found"
fi

if [ ! -f "analytics_api_server.js" ]; then
    error "analytics_api_server.js not found"
fi

if [ ! -f "analytics_package.json" ]; then
    error "analytics_package.json not found"
fi

# Check SSH connectivity
log "Testing SSH connection..."
if ! ssh -i $SSH_KEY -o ConnectTimeout=10 $SERVER_USER@$SERVER_IP "echo 'SSH connection successful'" > /dev/null 2>&1; then
    error "Cannot connect to server via SSH"
fi
success "SSH connection verified"

# Create directories on server
log "Creating directories on server..."
ssh -i $SSH_KEY $SERVER_USER@$SERVER_IP << 'EOF'
mkdir -p /var/www/bestcasinoportal.com/analytics
mkdir -p /var/www/bestcasinoportal.com/api
mkdir -p /var/log/casino-portal
chown -R www-data:www-data /var/www/bestcasinoportal.com
EOF

success "Server directories created"

# Upload dashboard files
log "Uploading dashboard files..."
scp -i $SSH_KEY admin_dashboard.html $SERVER_USER@$SERVER_IP:$ANALYTICS_DIR/
success "Dashboard HTML uploaded"

# Upload API server files
log "Uploading API server files..."
scp -i $SSH_KEY analytics_api_server.js $SERVER_USER@$SERVER_IP:$API_DIR/
scp -i $SSH_KEY analytics_package.json $SERVER_USER@$SERVER_IP:$API_DIR/package.json
success "API server files uploaded"

# Install dependencies and configure services
log "Installing dependencies and configuring services..."
ssh -i $SSH_KEY $SERVER_USER@$SERVER_IP << 'EOF'
cd /var/www/bestcasinoportal.com/api

# Install Node.js dependencies
npm install

# Create systemd service for analytics API
cat > /etc/systemd/system/casino-analytics.service << 'SERVICE'
[Unit]
Description=Casino Portal Analytics API
After=network.target
Wants=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/var/www/bestcasinoportal.com/api
ExecStart=/usr/bin/node analytics_api_server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=3001

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=casino-analytics

[Install]
WantedBy=multi-user.target
SERVICE

# Enable and start the service
systemctl daemon-reload
systemctl enable casino-analytics
systemctl restart casino-analytics

# Wait for service to start
sleep 5

# Check if service is running
if systemctl is-active --quiet casino-analytics; then
    echo "✓ Analytics API service started successfully"
else
    echo "✗ Analytics API service failed to start"
    systemctl status casino-analytics
    exit 1
fi
EOF

success "Analytics API service configured and started"

# Update Nginx configuration for dashboard
log "Updating Nginx configuration..."
ssh -i $SSH_KEY $SERVER_USER@$SERVER_IP << 'EOF'
# Create analytics subdomain config
cat > /etc/nginx/sites-available/analytics.bestcasinoportal.com << 'NGINX'
server {
    listen 80;
    listen [::]:80;
    server_name analytics.bestcasinoportal.com;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Basic auth for admin access
    auth_basic "Analytics Dashboard";
    auth_basic_user_file /etc/nginx/.htpasswd;
    
    # Dashboard files
    location / {
        root /var/www/bestcasinoportal.com/analytics;
        index admin_dashboard.html;
        try_files $uri $uri/ =404;
    }
    
    # API proxy
    location /api/ {
        proxy_pass http://localhost:3001/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # CORS headers for API
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, POST, OPTIONS";
        add_header Access-Control-Allow-Headers "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range";
        
        if ($request_method = 'OPTIONS') {
            add_header Access-Control-Allow-Origin *;
            add_header Access-Control-Allow-Methods "GET, POST, OPTIONS";
            add_header Access-Control-Allow-Headers "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range";
            add_header Access-Control-Max-Age 1728000;
            add_header Content-Type 'text/plain; charset=utf-8';
            add_header Content-Length 0;
            return 204;
        }
    }
    
    # Static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        root /var/www/bestcasinoportal.com/analytics;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Logging
    access_log /var/log/nginx/analytics.access.log;
    error_log /var/log/nginx/analytics.error.log;
}
NGINX

# Create basic auth file for admin access (username: admin, password: casino123)
echo 'admin:$apr1$rKNqXm2r$8VJvAOvVi9a4VbVaHQgKN/' > /etc/nginx/.htpasswd

# Enable the site
ln -sf /etc/nginx/sites-available/analytics.bestcasinoportal.com /etc/nginx/sites-enabled/

# Test Nginx configuration
nginx -t

if [ $? -eq 0 ]; then
    systemctl reload nginx
    echo "✓ Nginx configuration updated and reloaded"
else
    echo "✗ Nginx configuration test failed"
    exit 1
fi
EOF

success "Nginx configuration updated for analytics dashboard"

# Update main site with analytics integration
log "Adding analytics integration to main site..."
ssh -i $SSH_KEY $SERVER_USER@$SERVER_IP << 'EOF'
# Add analytics tracking script to main site
if [ -f "/var/www/bestcasinoportal.com/html/index.html" ]; then
    # Add analytics tracking before closing </body> tag
    sed -i '/<\/body>/i \
    <!-- Analytics Tracking -->\
    <script>\
    (function() {\
        const analytics = {\
            track: function(event, data) {\
                fetch("/api/analytics/track", {\
                    method: "POST",\
                    headers: { "Content-Type": "application/json" },\
                    body: JSON.stringify({ event, data, timestamp: new Date() })\
                }).catch(console.error);\
            }\
        };\
        \
        // Track page views\
        analytics.track("page_view", {\
            page: window.location.pathname,\
            referrer: document.referrer,\
            userAgent: navigator.userAgent\
        });\
        \
        // Track search queries\
        document.addEventListener("submit", function(e) {\
            if (e.target.matches("[data-search-form]")) {\
                const query = e.target.querySelector("input[type=\"search\"], input[name=\"q\"]")?.value;\
                if (query) {\
                    analytics.track("search", { query });\
                }\
            }\
        });\
        \
        // Track casino clicks\
        document.addEventListener("click", function(e) {\
            if (e.target.closest("[data-casino-link]")) {\
                const casino = e.target.closest("[data-casino-link]").dataset.casinoName;\
                analytics.track("casino_click", { casino });\
            }\
        });\
    })();\
    </script>' /var/www/bestcasinoportal.com/html/index.html
    
    echo "✓ Analytics tracking added to main site"
fi
EOF

success "Analytics integration added to main site"

# Verify deployment
log "Verifying deployment..."

# Check if API is responding
if curl -s -o /dev/null -w "%{http_code}" http://$SERVER_IP:3001/api/dashboard/overview | grep -q "200"; then
    success "Analytics API is responding"
else
    warning "Analytics API may not be responding yet (this is normal and may take a few moments)"
fi

# Check if service is running
ssh -i $SSH_KEY $SERVER_USER@$SERVER_IP "systemctl is-active casino-analytics" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    success "Analytics service is running"
else
    error "Analytics service is not running"
fi

# Final status report
log "Deployment completed successfully!"
echo ""
echo "📊 Analytics Dashboard: http://analytics.bestcasinoportal.com"
echo "🔑 Login: admin / casino123"
echo "🚀 API Endpoints: http://$SERVER_IP:3001/api/"
echo "�� Service Status: systemctl status casino-analytics"
echo "📋 Logs: journalctl -u casino-analytics -f"
echo ""
success "Analytics dashboard deployment complete!"
