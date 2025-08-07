#!/bin/bash
set -e

echo "🔒 PROFESSIONAL SSL SETUP FOR BESTCASINOPORTAL.COM"
echo "=================================================="

# Variables
DOMAIN="bestcasinoportal.com"
EMAIL="admin@bestcasinoportal.com"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root"
   exit 1
fi

echo "📋 Pre-flight checks..."
nginx -t || {
    echo "❌ Nginx configuration invalid"
    exit 1
}

# Install Certbot if not present
if ! command -v certbot &> /dev/null; then
    echo "📦 Installing Certbot..."
    apt update
    apt install -y certbot python3-certbot-nginx
fi

# Stop nginx temporarily for standalone certification
systemctl stop nginx

echo "🔒 Obtaining SSL certificate..."
certbot certonly --standalone \
    -d $DOMAIN \
    -d www.$DOMAIN \
    --non-interactive \
    --agree-tos \
    --email $EMAIL \
    --expand

# Start nginx back up
systemctl start nginx

# Configure nginx for SSL
echo "⚙️ Configuring Nginx for SSL..."
certbot --nginx \
    -d $DOMAIN \
    -d www.$DOMAIN \
    --non-interactive \
    --agree-tos \
    --email $EMAIL \
    --redirect

# Test SSL configuration
echo "🧪 Testing SSL configuration..."
nginx -t

# Reload nginx
systemctl reload nginx

# Setup automatic renewal
echo "🔄 Setting up automatic renewal..."
(crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -

# Test renewal
certbot renew --dry-run

echo "✅ SSL SETUP COMPLETED SUCCESSFULLY!"
echo "🌐 Website should now be accessible at https://$DOMAIN"

# Final verification
sleep 5
curl -I https://$DOMAIN || echo "⚠️ SSL verification failed"
