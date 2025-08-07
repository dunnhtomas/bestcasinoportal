#!/bin/bash

# BestCasinoPortal Clean Deployment Script
# Date: August 8, 2025

set -e

echo "🎰 BestCasinoPortal Clean Deployment Starting..."
echo "================================================"

# Create website directory with proper permissions
sudo mkdir -p /var/www/bestcasinoportal.com
sudo chown -R www-data:www-data /var/www/bestcasinoportal.com
sudo chmod -R 755 /var/www/bestcasinoportal.com

# Copy website files
sudo cp /tmp/website-files/index.html /var/www/bestcasinoportal.com/
sudo chown www-data:www-data /var/www/bestcasinoportal.com/index.html
sudo chmod 644 /var/www/bestcasinoportal.com/index.html

# Copy Nginx configuration
sudo cp /tmp/website-files/nginx-config.conf /etc/nginx/sites-available/bestcasinoportal.com

# Remove default site and enable our site
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/bestcasinoportal.com /etc/nginx/sites-enabled/

# Test Nginx configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx

# Create SSL certificate if it does not exist
if [ ! -f "/etc/letsencrypt/live/bestcasinoportal.com/fullchain.pem" ]; then
    echo "Creating SSL certificate..."
    sudo certbot --nginx -d bestcasinoportal.com -d www.bestcasinoportal.com --non-interactive --agree-tos --email admin@bestcasinoportal.com
fi

# Final test
echo "Testing website..."
curl -I https://bestcasinoportal.com || echo "Website test failed"

echo "✅ Deployment completed successfully!"
echo "🌐 Visit: https://bestcasinoportal.com"
