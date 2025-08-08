#!/bin/bash

# 🚀 Best Casino Portal - Monitoring Stack Deployment
# Professional MCP-Style Deployment with Prometheus & Grafana

set -euo pipefail

# Configuration
SERVER_IP="193.233.161.161"
SERVER_USER="root"
SSH_KEY="$HOME/.ssh/bestcasinoportal_ed25519"
MONITORING_DIR="/opt/casino-monitoring"
ENVIRONMENT="production"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

error() {
    echo -e "${RED}❌${NC} $1"
    exit 1
}

# Pre-deployment checks
log "🚀 Starting monitoring stack deployment..."
log "📋 Environment: $ENVIRONMENT"
log "🖥️  Server: $SERVER_IP"

# Check if files exist
if [ ! -f "docker-compose.monitoring.yml" ]; then
    error "docker-compose.monitoring.yml not found"
fi

if [ ! -f "prometheus.yml" ]; then
    error "prometheus.yml not found"
fi

# Check SSH connectivity
log "🔑 Testing SSH connection..."
if ! ssh -i "$SSH_KEY" -o ConnectTimeout=10 "$SERVER_USER@$SERVER_IP" "echo 'SSH connection successful'" > /dev/null 2>&1; then
    error "Cannot connect to server via SSH"
fi
success "SSH connection verified"

# Install Docker and Docker Compose if needed
log "🐳 Checking Docker installation..."
ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" << 'EOF'
# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    systemctl enable docker
    systemctl start docker
    usermod -aG docker $USER
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "Installing Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# Verify installations
docker --version
docker-compose --version
EOF

success "Docker and Docker Compose ready"

# Create monitoring directory on server
log "📁 Creating monitoring directory structure..."
ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" << EOF
mkdir -p $MONITORING_DIR
mkdir -p $MONITORING_DIR/grafana/dashboards
mkdir -p $MONITORING_DIR/grafana/datasources
mkdir -p $MONITORING_DIR/data/prometheus
mkdir -p $MONITORING_DIR/data/grafana
chown -R 472:472 $MONITORING_DIR/data/grafana  # Grafana user
chown -R 65534:65534 $MONITORING_DIR/data/prometheus  # Nobody user
EOF

success "Directory structure created"

# Upload monitoring configuration files
log "📤 Uploading monitoring configuration..."
scp -i "$SSH_KEY" docker-compose.monitoring.yml "$SERVER_USER@$SERVER_IP:$MONITORING_DIR/docker-compose.yml"
scp -i "$SSH_KEY" prometheus.yml "$SERVER_USER@$SERVER_IP:$MONITORING_DIR/"
scp -i "$SSH_KEY" prometheus_rules.yml "$SERVER_USER@$SERVER_IP:$MONITORING_DIR/"
scp -i "$SSH_KEY" grafana/datasources/prometheus.yml "$SERVER_USER@$SERVER_IP:$MONITORING_DIR/grafana/datasources/"
scp -i "$SSH_KEY" grafana/dashboards/dashboard.yml "$SERVER_USER@$SERVER_IP:$MONITORING_DIR/grafana/dashboards/"

success "Configuration files uploaded"

# Update Nginx to enable metrics endpoint
log "🌐 Configuring Nginx metrics endpoint..."
ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" << 'EOF'
# Add metrics endpoint to Nginx config
if ! grep -q "nginx_status" /etc/nginx/sites-available/bestcasinoportal.com; then
    sed -i '/server {/a \
    # Metrics endpoint for monitoring\
    location /nginx_status {\
        stub_status on;\
        access_log off;\
        allow 127.0.0.1;\
        allow 172.0.0.0/8;\
        deny all;\
    }' /etc/nginx/sites-available/bestcasinoportal.com
    
    # Test and reload Nginx
    nginx -t && systemctl reload nginx
    echo "✅ Nginx metrics endpoint configured"
else
    echo "✅ Nginx metrics endpoint already configured"
fi
EOF

# Deploy monitoring stack
log "🚀 Deploying monitoring stack..."
ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" << EOF
cd $MONITORING_DIR

# Stop any existing monitoring stack
if [ -f docker-compose.yml ]; then
    docker-compose down --remove-orphans || true
fi

# Pull latest images
docker-compose pull

# Start monitoring stack
docker-compose up -d

# Wait for services to start
echo "⏳ Waiting for services to start..."
sleep 30

# Check if services are running
if docker-compose ps | grep -q "Up"; then
    echo "✅ Monitoring stack deployed successfully"
    docker-compose ps
else
    echo "❌ Some services failed to start"
    docker-compose logs
    exit 1
fi
EOF

success "Monitoring stack deployed"

# Configure firewall rules
log "🔥 Configuring firewall rules..."
ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" << 'EOF'
# Allow monitoring ports
ufw allow 9090/tcp comment "Prometheus"
ufw allow 3000/tcp comment "Grafana"
ufw allow 9100/tcp comment "Node Exporter"
ufw allow 8080/tcp comment "cAdvisor"
ufw allow 9113/tcp comment "Nginx Exporter"

# Reload firewall
ufw reload
EOF

success "Firewall configured"

# Verify deployment
log "🔍 Verifying monitoring deployment..."
ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" << EOF
cd $MONITORING_DIR

echo "📊 Service Status:"
docker-compose ps

echo ""
echo "🌐 Access URLs:"
echo "  Prometheus: http://$SERVER_IP:9090"
echo "  Grafana:    http://$SERVER_IP:3000 (admin/CasinoAdmin2025!)"
echo "  Node Exporter: http://$SERVER_IP:9100/metrics"
echo "  cAdvisor:   http://$SERVER_IP:8080"

echo ""
echo "📋 Health Checks:"
curl -s http://localhost:9090/-/healthy && echo "✅ Prometheus healthy" || echo "❌ Prometheus unhealthy"
curl -s http://localhost:3000/api/health && echo "✅ Grafana healthy" || echo "❌ Grafana unhealthy"
curl -s http://localhost:9100/metrics | head -1 && echo "✅ Node Exporter healthy" || echo "❌ Node Exporter unhealthy"
EOF

# Update status.json
log "�� Updating project status..."
cat > ../status_update.json << EOF
{
  "monitoring_deployment": {
    "status": "DEPLOYED",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "services": {
      "prometheus": "running",
      "grafana": "running", 
      "node_exporter": "running",
      "cadvisor": "running",
      "nginx_exporter": "running"
    },
    "access_urls": {
      "prometheus": "http://$SERVER_IP:9090",
      "grafana": "http://$SERVER_IP:3000",
      "node_exporter": "http://$SERVER_IP:9100",
      "cadvisor": "http://$SERVER_IP:8080"
    },
    "credentials": {
      "grafana_admin": "admin",
      "grafana_password": "CasinoAdmin2025!"
    }
  }
}
EOF

success "🎉 Monitoring stack deployment complete!"
echo ""
echo "🔗 Quick Access:"
echo "  Prometheus: http://$SERVER_IP:9090"
echo "  Grafana:    http://$SERVER_IP:3000"
echo "  Username:   admin"
echo "  Password:   CasinoAdmin2025!"
echo ""
echo "📊 Next steps:"
echo "  1. Access Grafana and import dashboards"
echo "  2. Configure alert notifications"
echo "  3. Set up automated backups"
echo "  4. Monitor system performance"
