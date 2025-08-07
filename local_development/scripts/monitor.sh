#!/bin/bash
set -euo pipefail

# Comprehensive Monitoring Script for BestCasinoPortal.com
# Real-time health monitoring and alerting

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DOMAIN="bestcasinoportal.com"
SERVER_IP="193.233.161.161"
LOG_FILE="/var/log/monitoring.log"
ALERT_EMAIL="admin@bestcasinoportal.com"
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

# Send alert email (if configured)
send_alert() {
    local subject="$1"
    local message="$2"
    
    if command -v mail >/dev/null 2>&1; then
        echo "$message" | mail -s "$subject" "$ALERT_EMAIL"
        log "Alert sent: $subject"
    else
        warning "Mail not configured - alert not sent: $subject"
    fi
}

# Check website accessibility
check_website() {
    log "Checking website accessibility..."
    
    local response_code=$(curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN" || echo "000")
    local response_time=$(curl -s -o /dev/null -w "%{time_total}" "https://$DOMAIN" || echo "999")
    
    if [[ "$response_code" == "200" ]]; then
        log "✓ Website is accessible (HTTP $response_code)"
        
        if (( $(echo "$response_time > 5.0" | bc -l) )); then
            warning "⚠ Slow response time: ${response_time}s"
        else
            log "✓ Response time: ${response_time}s"
        fi
    else
        error "✗ Website is not accessible (HTTP $response_code)"
        send_alert "Website Down" "BestCasinoPortal.com is returning HTTP $response_code"
        return 1
    fi
}

# Check SSL certificate
check_ssl() {
    log "Checking SSL certificate..."
    
    local ssl_expiry=$(echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)
    local ssl_expiry_epoch=$(date -d "$ssl_expiry" +%s)
    local current_epoch=$(date +%s)
    local days_until_expiry=$(( (ssl_expiry_epoch - current_epoch) / 86400 ))
    
    if [[ $days_until_expiry -gt 30 ]]; then
        log "✓ SSL certificate valid ($days_until_expiry days remaining)"
    elif [[ $days_until_expiry -gt 7 ]]; then
        warning "⚠ SSL certificate expires in $days_until_expiry days"
        send_alert "SSL Certificate Warning" "SSL certificate for $DOMAIN expires in $days_until_expiry days"
    else
        error "✗ SSL certificate expires in $days_until_expiry days"
        send_alert "SSL Certificate Critical" "SSL certificate for $DOMAIN expires in $days_until_expiry days"
        return 1
    fi
}

# Check API health
check_api() {
    log "Checking API health..."
    
    local api_response=$(curl -s "https://$DOMAIN/health" || echo '{"status":"error"}')
    local api_status=$(echo "$api_response" | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "error")
    
    if [[ "$api_status" == "healthy" ]]; then
        log "✓ API is healthy"
        
        # Test API endpoints
        local casinos_response=$(curl -s "https://$DOMAIN/api/casinos" || echo '{"success":false}')
        local casinos_success=$(echo "$casinos_response" | grep -o '"success":[^,}]*' | cut -d':' -f2 || echo "false")
        
        if [[ "$casinos_success" == "true" ]]; then
            log "✓ API endpoints are working"
        else
            warning "⚠ API endpoints may have issues"
        fi
    else
        error "✗ API health check failed"
        send_alert "API Down" "BestCasinoPortal API health check failed"
        return 1
    fi
}

# Check server resources
check_server_resources() {
    log "Checking server resources..."
    
    ssh -i "$SSH_KEY" root@"$SERVER_IP" << 'EOSSH'
        # Check disk usage
        DISK_USAGE=$(df / | awk 'NR==2{print $5}' | sed 's/%//')
        echo "Disk usage: ${DISK_USAGE}%"
        
        if [[ $DISK_USAGE -gt 90 ]]; then
            echo "ERROR: Critical disk usage: ${DISK_USAGE}%"
            exit 1
        elif [[ $DISK_USAGE -gt 80 ]]; then
            echo "WARNING: High disk usage: ${DISK_USAGE}%"
        else
            echo "OK: Disk usage normal: ${DISK_USAGE}%"
        fi
        
        # Check memory usage
        MEMORY_USAGE=$(free | grep Mem | awk '{printf("%.1f", $3/$2 * 100.0)}')
        echo "Memory usage: ${MEMORY_USAGE}%"
        
        if (( $(echo "$MEMORY_USAGE > 90" | bc -l) )); then
            echo "ERROR: Critical memory usage: ${MEMORY_USAGE}%"
            exit 1
        elif (( $(echo "$MEMORY_USAGE > 80" | bc -l) )); then
            echo "WARNING: High memory usage: ${MEMORY_USAGE}%"
        else
            echo "OK: Memory usage normal: ${MEMORY_USAGE}%"
        fi
        
        # Check CPU load
        LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
        echo "Load average: $LOAD_AVG"
        
        if (( $(echo "$LOAD_AVG > 4.0" | bc -l) )); then
            echo "ERROR: High CPU load: $LOAD_AVG"
            exit 1
        elif (( $(echo "$LOAD_AVG > 2.0" | bc -l) )); then
            echo "WARNING: Elevated CPU load: $LOAD_AVG"
        else
            echo "OK: CPU load normal: $LOAD_AVG"
        fi
EOSSH
    
    local ssh_exit_code=$?
    
    if [[ $ssh_exit_code -eq 0 ]]; then
        log "✓ Server resources are normal"
    else
        error "✗ Server resource issues detected"
        send_alert "Server Resources Critical" "High resource usage detected on BestCasinoPortal server"
        return 1
    fi
}

# Check services status
check_services() {
    log "Checking services status..."
    
    ssh -i "$SSH_KEY" root@"$SERVER_IP" << 'EOSSH'
        # Check Nginx
        if systemctl is-active --quiet nginx; then
            echo "OK: Nginx is running"
        else
            echo "ERROR: Nginx is not running"
            systemctl start nginx
            exit 1
        fi
        
        # Check API server
        if systemctl is-active --quiet bestcasinoportal-api; then
            echo "OK: API server is running"
        else
            echo "ERROR: API server is not running"
            systemctl start bestcasinoportal-api
            exit 1
        fi
        
        # Check fail2ban
        if systemctl is-active --quiet fail2ban; then
            echo "OK: Fail2ban is running"
        else
            echo "WARNING: Fail2ban is not running"
            systemctl start fail2ban
        fi
        
        # Check UFW firewall
        if ufw status | grep -q "Status: active"; then
            echo "OK: Firewall is active"
        else
            echo "WARNING: Firewall is not active"
        fi
EOSSH
    
    local ssh_exit_code=$?
    
    if [[ $ssh_exit_code -eq 0 ]]; then
        log "✓ All services are running"
    else
        error "✗ Some services have issues"
        send_alert "Service Issues" "Service issues detected on BestCasinoPortal server"
        return 1
    fi
}

# Check logs for errors
check_logs() {
    log "Checking logs for errors..."
    
    ssh -i "$SSH_KEY" root@"$SERVER_IP" << 'EOSSH'
        # Check Nginx error log
        NGINX_ERRORS=$(tail -n 100 /var/log/nginx/error.log | grep -c "$(date +'%Y/%m/%d')" || echo 0)
        echo "Nginx errors today: $NGINX_ERRORS"
        
        if [[ $NGINX_ERRORS -gt 50 ]]; then
            echo "WARNING: High number of Nginx errors: $NGINX_ERRORS"
        fi
        
        # Check systemd journal for API server errors
        API_ERRORS=$(journalctl -u bestcasinoportal-api --since today | grep -c "ERROR" || echo 0)
        echo "API server errors today: $API_ERRORS"
        
        if [[ $API_ERRORS -gt 10 ]]; then
            echo "WARNING: High number of API errors: $API_ERRORS"
        fi
EOSSH
    
    log "✓ Log check completed"
}

# Generate monitoring report
generate_report() {
    log "Generating monitoring report..."
    
    local report_file="/tmp/monitoring_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
BestCasinoPortal.com Monitoring Report
Generated: $(date)

=== System Status ===
Website: https://$DOMAIN
Server: $SERVER_IP

=== Health Checks ===
- Website Accessibility: $(check_website >/dev/null 2>&1 && echo "✓ PASS" || echo "✗ FAIL")
- SSL Certificate: $(check_ssl >/dev/null 2>&1 && echo "✓ PASS" || echo "✗ FAIL") 
- API Health: $(check_api >/dev/null 2>&1 && echo "✓ PASS" || echo "✗ FAIL")
- Server Resources: $(check_server_resources >/dev/null 2>&1 && echo "✓ PASS" || echo "✗ FAIL")
- Services Status: $(check_services >/dev/null 2>&1 && echo "✓ PASS" || echo "✗ FAIL")

=== Recommendations ===
- Monitor trends for capacity planning
- Review security logs regularly
- Update dependencies monthly
- Test backup restoration quarterly

Report saved to: $report_file
EOF
    
    log "✓ Report generated: $report_file"
}

# Main monitoring function
main() {
    log "🔍 Starting comprehensive monitoring for BestCasinoPortal.com..."
    
    local overall_status=0
    
    check_website || overall_status=1
    check_ssl || overall_status=1
    check_api || overall_status=1
    check_server_resources || overall_status=1
    check_services || overall_status=1
    check_logs
    
    if [[ $overall_status -eq 0 ]]; then
        log "🎉 All monitoring checks passed!"
    else
        error "❌ Some monitoring checks failed - review logs"
    fi
    
    # Generate report if requested
    if [[ "${1:-}" == "--report" ]]; then
        generate_report
    fi
    
    return $overall_status
}

# Run main function
main "$@"
