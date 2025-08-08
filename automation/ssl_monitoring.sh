#!/bin/bash

# 🔐 Best Casino Portal - SSL Certificate Monitoring & Automation
# Professional SSL Management and Monitoring System

set -euo pipefail

# Configuration
DOMAIN="bestcasinoportal.com"
CLOUDFLARE_TOKEN="pe2L5nDoK0kKvpGVkRSm4P48FExlWfbTZdOZfhXF"
ALERT_EMAIL="admin@bestcasinoportal.com"
WARNING_DAYS=30
CRITICAL_DAYS=7
LOG_FILE="/var/log/ssl-monitor.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}✅${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}⚠️${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}❌${NC} $1" | tee -a "$LOG_FILE"
}

# Check SSL certificate expiry
check_ssl_expiry() {
    local domain="$1"
    
    log "🔐 Checking SSL certificate for $domain"
    
    # Get certificate expiry date
    local expiry_date=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | \
                       openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
    
    if [ -z "$expiry_date" ]; then
        error "Could not retrieve SSL certificate for $domain"
        return 1
    fi
    
    # Convert to epoch time
    local expiry_epoch=$(date -d "$expiry_date" +%s)
    local current_epoch=$(date +%s)
    local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
    
    log "Certificate expires: $expiry_date (in $days_until_expiry days)"
    
    # Check expiry status
    if [ $days_until_expiry -le $CRITICAL_DAYS ]; then
        error "SSL certificate expires in $days_until_expiry days - CRITICAL!"
        send_alert "CRITICAL" "$domain" "$days_until_expiry" "$expiry_date"
        return 2
    elif [ $days_until_expiry -le $WARNING_DAYS ]; then
        warning "SSL certificate expires in $days_until_expiry days"
        send_alert "WARNING" "$domain" "$days_until_expiry" "$expiry_date"
        return 1
    else
        success "SSL certificate is valid for $days_until_expiry days"
        return 0
    fi
}

# Check SSL configuration
check_ssl_config() {
    local domain="$1"
    
    log "🔧 Checking SSL configuration for $domain"
    
    # Test SSL Labs API (simplified check)
    local ssl_grade=$(curl -s "https://api.ssllabs.com/api/v3/analyze?host=$domain&publish=off&startNew=off&all=done" | \
                     jq -r '.endpoints[0].grade // "Unknown"' 2>/dev/null || echo "Unknown")
    
    if [ "$ssl_grade" = "A+" ] || [ "$ssl_grade" = "A" ]; then
        success "SSL configuration grade: $ssl_grade"
    elif [ "$ssl_grade" = "Unknown" ]; then
        warning "Could not determine SSL grade"
    else
        warning "SSL configuration grade: $ssl_grade (consider improvement)"
    fi
    
    # Check certificate chain
    local chain_status=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | \
                        openssl verify 2>&1 | grep -c "OK" || echo "0")
    
    if [ "$chain_status" -gt 0 ]; then
        success "SSL certificate chain is valid"
    else
        warning "SSL certificate chain may have issues"
    fi
    
    # Check for mixed content
    local https_status=$(curl -s -o /dev/null -w "%{http_code}" "https://$domain")
    if [ "$https_status" = "200" ]; then
        success "HTTPS is accessible"
    else
        warning "HTTPS returned status code: $https_status"
    fi
}

# Check Cloudflare SSL settings
check_cloudflare_ssl() {
    log "☁️ Checking Cloudflare SSL settings"
    
    # Get zone ID
    local zone_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" \
                   -H "Authorization: Bearer $CLOUDFLARE_TOKEN" \
                   -H "Content-Type: application/json" | \
                   jq -r '.result[0].id // empty')
    
    if [ -z "$zone_id" ]; then
        error "Could not retrieve Cloudflare zone ID"
        return 1
    fi
    
    # Get SSL settings
    local ssl_settings=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/settings/ssl" \
                        -H "Authorization: Bearer $CLOUDFLARE_TOKEN" \
                        -H "Content-Type: application/json")
    
    local ssl_mode=$(echo "$ssl_settings" | jq -r '.result.value // "unknown"')
    local ssl_status=$(echo "$ssl_settings" | jq -r '.success // false')
    
    if [ "$ssl_status" = "true" ]; then
        success "Cloudflare SSL mode: $ssl_mode"
        
        # Check if optimal settings
        if [ "$ssl_mode" = "full" ] || [ "$ssl_mode" = "strict" ]; then
            success "Cloudflare SSL mode is optimal"
        else
            warning "Consider upgrading Cloudflare SSL mode to 'Full' or 'Full (strict)'"
        fi
    else
        error "Could not retrieve Cloudflare SSL settings"
    fi
    
    # Check Always Use HTTPS
    local https_redirect=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/settings/always_use_https" \
                          -H "Authorization: Bearer $CLOUDFLARE_TOKEN" \
                          -H "Content-Type: application/json" | \
                          jq -r '.result.value // "unknown"')
    
    if [ "$https_redirect" = "on" ]; then
        success "Always Use HTTPS is enabled"
    else
        warning "Always Use HTTPS is not enabled"
    fi
}

# Renew SSL certificate
renew_ssl_certificate() {
    log "🔄 Renewing SSL certificate"
    
    # Check if certbot is available
    if ! command -v certbot &> /dev/null; then
        error "Certbot is not installed"
        return 1
    fi
    
    # Dry run first
    log "Performing dry run renewal..."
    if certbot renew --dry-run --quiet; then
        success "Dry run renewal successful"
    else
        error "Dry run renewal failed"
        return 1
    fi
    
    # Actual renewal
    log "Performing actual renewal..."
    if certbot renew --quiet; then
        success "SSL certificate renewal successful"
        
        # Reload nginx
        if systemctl reload nginx; then
            success "Nginx reloaded successfully"
        else
            warning "Failed to reload Nginx"
        fi
        
        return 0
    else
        error "SSL certificate renewal failed"
        return 1
    fi
}

# Send alert notification
send_alert() {
    local severity="$1"
    local domain="$2"
    local days="$3"
    local expiry_date="$4"
    
    log "📧 Sending $severity alert for $domain"
    
    # Create alert payload
    local alert_data=$(cat << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "severity": "$severity",
  "domain": "$domain",
  "days_until_expiry": $days,
  "expiry_date": "$expiry_date",
  "message": "SSL certificate for $domain expires in $days days",
  "action": "$([ $days -le $CRITICAL_DAYS ] && echo "IMMEDIATE ACTION REQUIRED" || echo "Monitor and prepare for renewal")"
}
EOF
)
    
    # Log to monitoring system
    echo "$alert_data" >> "/var/log/ssl-alerts.json"
    
    # Send to monitoring endpoint (if configured)
    if command -v curl &> /dev/null; then
        curl -s -X POST "http://localhost:3001/api/alerts/ssl" \
             -H "Content-Type: application/json" \
             -d "$alert_data" || true
    fi
    
    success "Alert sent for $domain"
}

# Generate SSL monitoring report
generate_report() {
    log "📊 Generating SSL monitoring report"
    
    local report_file="/var/log/ssl-report-$(date +%Y%m%d_%H%M%S).json"
    
    # Check main domain
    local domain_status="unknown"
    local domain_days=0
    local domain_expiry=""
    
    if check_ssl_expiry "$DOMAIN"; then
        domain_status="valid"
    else
        domain_status="warning"
    fi
    
    # Get detailed certificate info
    local cert_info=$(echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null | \
                     openssl x509 -noout -text 2>/dev/null)
    
    local issuer=$(echo "$cert_info" | grep "Issuer:" | head -1 | cut -d: -f2- | xargs)
    local subject=$(echo "$cert_info" | grep "Subject:" | head -1 | cut -d: -f2- | xargs)
    
    # Create comprehensive report
    cat > "$report_file" << EOF
{
  "report_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "domain": "$DOMAIN",
  "ssl_status": {
    "status": "$domain_status",
    "days_until_expiry": $domain_days,
    "expiry_date": "$domain_expiry",
    "issuer": "$issuer",
    "subject": "$subject"
  },
  "configuration": {
    "cloudflare_ssl_mode": "$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" -H "Authorization: Bearer $CLOUDFLARE_TOKEN" | jq -r '.result[0].id')/settings/ssl" -H "Authorization: Bearer $CLOUDFLARE_TOKEN" | jq -r '.result.value')",
    "https_redirect": "$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" -H "Authorization: Bearer $CLOUDFLARE_TOKEN" | jq -r '.result[0].id')/settings/always_use_https" -H "Authorization: Bearer $CLOUDFLARE_TOKEN" | jq -r '.result.value')"
  },
  "recommendations": [
    "$([ $domain_days -le $WARNING_DAYS ] && echo "Schedule SSL certificate renewal" || echo "SSL certificate is valid")",
    "Monitor SSL grade regularly",
    "Ensure Cloudflare SSL mode is set to Full (strict)",
    "Enable HSTS headers for enhanced security"
  ]
}
EOF

    success "SSL monitoring report generated: $report_file"
}

# Update monitoring dashboard
update_monitoring_dashboard() {
    log "📊 Updating monitoring dashboard with SSL metrics"
    
    # Send SSL metrics to monitoring system
    local ssl_expiry_days=$(check_ssl_expiry "$DOMAIN" 2>/dev/null | grep -o '[0-9]\+ days' | grep -o '[0-9]\+' || echo "0")
    
    # Create metrics payload
    local metrics_data=$(cat << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "metrics": {
    "ssl_certificate_expiry_days": $ssl_expiry_days,
    "ssl_status": "$([ $ssl_expiry_days -gt $WARNING_DAYS ] && echo "valid" || echo "warning")",
    "domain": "$DOMAIN"
  }
}
EOF
)
    
    # Send to analytics API
    if curl -s -X POST "http://localhost:3001/api/metrics/ssl" \
            -H "Content-Type: application/json" \
            -d "$metrics_data" > /dev/null; then
        success "SSL metrics updated in monitoring dashboard"
    else
        warning "Could not update monitoring dashboard"
    fi
}

# Auto-renewal setup
setup_auto_renewal() {
    log "⚙️ Setting up SSL auto-renewal"
    
    # Create renewal script
    cat > /opt/ssl-auto-renew.sh << 'EOF'
#!/bin/bash
# Auto-renewal script for SSL certificates

LOG_FILE="/var/log/ssl-renewal.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "Starting SSL auto-renewal process"

# Check if renewal is needed (within 30 days)
if certbot renew --dry-run --quiet; then
    log "Renewal check passed, proceeding with renewal"
    
    if certbot renew --quiet; then
        log "SSL certificate renewed successfully"
        
        # Reload services
        systemctl reload nginx
        systemctl restart casino-api
        systemctl restart casino-analytics
        
        log "Services restarted after SSL renewal"
        
        # Send success notification
        curl -s -X POST "http://localhost:3001/api/notifications/ssl" \
             -H "Content-Type: application/json" \
             -d '{"status": "success", "message": "SSL certificate renewed successfully"}' || true
    else
        log "SSL certificate renewal failed"
        
        # Send failure notification
        curl -s -X POST "http://localhost:3001/api/notifications/ssl" \
             -H "Content-Type: application/json" \
             -d '{"status": "error", "message": "SSL certificate renewal failed"}' || true
    fi
else
    log "SSL renewal check failed"
fi

log "SSL auto-renewal process completed"
EOF

    chmod +x /opt/ssl-auto-renew.sh
    
    # Add to crontab (run twice daily)
    (crontab -l 2>/dev/null; echo "0 */12 * * * /opt/ssl-auto-renew.sh") | crontab -
    
    success "SSL auto-renewal configured"
}

# Main monitoring function
monitor_ssl() {
    log "🚀 Starting SSL monitoring cycle"
    
    # Check SSL certificate expiry
    check_ssl_expiry "$DOMAIN"
    
    # Check SSL configuration
    check_ssl_config "$DOMAIN"
    
    # Check Cloudflare settings
    check_cloudflare_ssl
    
    # Update monitoring dashboard
    update_monitoring_dashboard
    
    # Generate report
    generate_report
    
    success "SSL monitoring cycle completed"
}

# Main execution
case "${1:-monitor}" in
    "monitor")
        monitor_ssl
        ;;
    "renew")
        renew_ssl_certificate
        ;;
    "setup")
        setup_auto_renewal
        ;;
    "report")
        generate_report
        ;;
    *)
        echo "Usage: $0 {monitor|renew|setup|report}"
        echo ""
        echo "Commands:"
        echo "  monitor  - Run SSL monitoring checks"
        echo "  renew    - Renew SSL certificate"
        echo "  setup    - Setup auto-renewal"
        echo "  report   - Generate SSL report"
        exit 1
        ;;
esac
