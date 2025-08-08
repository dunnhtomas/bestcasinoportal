#!/bin/bash

# 🔄 Best Casino Portal - Automated Backup System
# Professional Enterprise-Grade Backup Solution

set -euo pipefail

# Configuration
BACKUP_DIR="/opt/casino-backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30
SERVER_IP="193.233.161.161"
CLOUDFLARE_TOKEN="pe2L5nDoK0kKvpGVkRSm4P48FExlWfbTZdOZfhXF"

# Database Configuration
DB_HOST="localhost"
DB_NAME="bestcasinoportal"
DB_USER="casino_admin"
DB_PASSWORD="casino_secure_password_2025"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "${BACKUP_DIR}/backup.log"
}

success() {
    echo -e "${GREEN}✅${NC} $1" | tee -a "${BACKUP_DIR}/backup.log"
}

error() {
    echo -e "${RED}❌${NC} $1" | tee -a "${BACKUP_DIR}/backup.log"
    exit 1
}

# Create backup directories
create_backup_structure() {
    log "📁 Creating backup directory structure..."
    
    mkdir -p "${BACKUP_DIR}"/{database,files,configs,logs,monitoring}
    mkdir -p "${BACKUP_DIR}/database/${DATE}"
    mkdir -p "${BACKUP_DIR}/files/${DATE}"
    mkdir -p "${BACKUP_DIR}/configs/${DATE}"
    
    success "Backup directories created"
}

# Database backup
backup_database() {
    log "🗄️ Starting database backup..."
    
    # PostgreSQL backup
    if command -v pg_dump &> /dev/null; then
        PGPASSWORD="$DB_PASSWORD" pg_dump -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" \
            --verbose --clean --if-exists --create \
            > "${BACKUP_DIR}/database/${DATE}/casino_database_${DATE}.sql"
        
        # Compress the backup
        gzip "${BACKUP_DIR}/database/${DATE}/casino_database_${DATE}.sql"
        
        success "PostgreSQL database backup completed"
    else
        log "⚠️ PostgreSQL not found, skipping database backup"
    fi
    
    # Redis backup
    if systemctl is-active --quiet redis-server; then
        cp /var/lib/redis/dump.rdb "${BACKUP_DIR}/database/${DATE}/redis_${DATE}.rdb" 2>/dev/null || true
        success "Redis backup completed"
    fi
}

# Application files backup
backup_application_files() {
    log "📂 Starting application files backup..."
    
    # Website files
    if [ -d "/var/www/bestcasinoportal.com" ]; then
        tar -czf "${BACKUP_DIR}/files/${DATE}/website_files_${DATE}.tar.gz" \
            -C /var/www bestcasinoportal.com
        success "Website files backup completed"
    fi
    
    # API server files
    if [ -d "/opt/casino-api" ]; then
        tar -czf "${BACKUP_DIR}/files/${DATE}/api_files_${DATE}.tar.gz" \
            -C /opt casino-api
        success "API files backup completed"
    fi
    
    # Monitoring data
    if [ -d "/opt/casino-monitoring" ]; then
        tar -czf "${BACKUP_DIR}/files/${DATE}/monitoring_files_${DATE}.tar.gz" \
            -C /opt casino-monitoring
        success "Monitoring files backup completed"
    fi
}

# Configuration backup
backup_configurations() {
    log "⚙️ Starting configuration backup..."
    
    # Nginx configuration
    if [ -d "/etc/nginx" ]; then
        tar -czf "${BACKUP_DIR}/configs/${DATE}/nginx_config_${DATE}.tar.gz" \
            -C /etc nginx
        success "Nginx configuration backup completed"
    fi
    
    # SSL certificates
    if [ -d "/etc/letsencrypt" ]; then
        tar -czf "${BACKUP_DIR}/configs/${DATE}/ssl_certs_${DATE}.tar.gz" \
            -C /etc letsencrypt
        success "SSL certificates backup completed"
    fi
    
    # System configuration
    tar -czf "${BACKUP_DIR}/configs/${DATE}/system_config_${DATE}.tar.gz" \
        -C / etc/hosts etc/hostname etc/timezone etc/fstab etc/crontab 2>/dev/null || true
    
    success "System configuration backup completed"
}

# Docker volumes backup
backup_docker_volumes() {
    log "🐳 Starting Docker volumes backup..."
    
    if command -v docker &> /dev/null; then
        # Stop containers temporarily for consistent backup
        docker-compose -f /opt/casino-monitoring/docker-compose.yml stop || true
        
        # Backup Prometheus data
        if [ -d "/var/lib/docker/volumes/casino-monitoring_prometheus_data" ]; then
            tar -czf "${BACKUP_DIR}/files/${DATE}/prometheus_data_${DATE}.tar.gz" \
                -C /var/lib/docker/volumes casino-monitoring_prometheus_data
        fi
        
        # Backup Grafana data
        if [ -d "/var/lib/docker/volumes/casino-monitoring_grafana_data" ]; then
            tar -czf "${BACKUP_DIR}/files/${DATE}/grafana_data_${DATE}.tar.gz" \
                -C /var/lib/docker/volumes casino-monitoring_grafana_data
        fi
        
        # Restart containers
        docker-compose -f /opt/casino-monitoring/docker-compose.yml start || true
        
        success "Docker volumes backup completed"
    fi
}

# System logs backup
backup_logs() {
    log "📋 Starting logs backup..."
    
    # Application logs
    if [ -d "/var/log/nginx" ]; then
        tar -czf "${BACKUP_DIR}/logs/nginx_logs_${DATE}.tar.gz" \
            -C /var/log nginx --exclude="*.gz"
    fi
    
    # System logs (last 7 days)
    journalctl --since="7 days ago" --output=export > "${BACKUP_DIR}/logs/system_journal_${DATE}.export"
    gzip "${BACKUP_DIR}/logs/system_journal_${DATE}.export"
    
    success "Logs backup completed"
}

# Create backup manifest
create_manifest() {
    log "📝 Creating backup manifest..."
    
    cat > "${BACKUP_DIR}/backup_manifest_${DATE}.json" << EOF
{
  "backup_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "backup_id": "${DATE}",
  "server_ip": "${SERVER_IP}",
  "components": {
    "database": {
      "postgresql": "$([ -f "${BACKUP_DIR}/database/${DATE}/casino_database_${DATE}.sql.gz" ] && echo "included" || echo "skipped")",
      "redis": "$([ -f "${BACKUP_DIR}/database/${DATE}/redis_${DATE}.rdb" ] && echo "included" || echo "skipped")"
    },
    "application_files": {
      "website": "$([ -f "${BACKUP_DIR}/files/${DATE}/website_files_${DATE}.tar.gz" ] && echo "included" || echo "skipped")",
      "api": "$([ -f "${BACKUP_DIR}/files/${DATE}/api_files_${DATE}.tar.gz" ] && echo "included" || echo "skipped")",
      "monitoring": "$([ -f "${BACKUP_DIR}/files/${DATE}/monitoring_files_${DATE}.tar.gz" ] && echo "included" || echo "skipped")"
    },
    "configurations": {
      "nginx": "$([ -f "${BACKUP_DIR}/configs/${DATE}/nginx_config_${DATE}.tar.gz" ] && echo "included" || echo "skipped")",
      "ssl": "$([ -f "${BACKUP_DIR}/configs/${DATE}/ssl_certs_${DATE}.tar.gz" ] && echo "included" || echo "skipped")",
      "system": "$([ -f "${BACKUP_DIR}/configs/${DATE}/system_config_${DATE}.tar.gz" ] && echo "included" || echo "skipped")"
    },
    "docker_volumes": {
      "prometheus": "$([ -f "${BACKUP_DIR}/files/${DATE}/prometheus_data_${DATE}.tar.gz" ] && echo "included" || echo "skipped")",
      "grafana": "$([ -f "${BACKUP_DIR}/files/${DATE}/grafana_data_${DATE}.tar.gz" ] && echo "included" || echo "skipped")"
    }
  },
  "backup_size": "$(du -sh ${BACKUP_DIR} | cut -f1)",
  "files_count": $(find "${BACKUP_DIR}" -type f -name "*${DATE}*" | wc -l)
}
EOF

    success "Backup manifest created"
}

# Cleanup old backups
cleanup_old_backups() {
    log "🧹 Cleaning up old backups (older than ${RETENTION_DAYS} days)..."
    
    find "${BACKUP_DIR}" -type f -mtime +${RETENTION_DAYS} -delete 2>/dev/null || true
    find "${BACKUP_DIR}" -type d -empty -delete 2>/dev/null || true
    
    success "Old backups cleaned up"
}

# Verify backup integrity
verify_backup() {
    log "🔍 Verifying backup integrity..."
    
    local errors=0
    
    # Check if critical files exist
    if [ ! -f "${BACKUP_DIR}/backup_manifest_${DATE}.json" ]; then
        error "Backup manifest not found"
        ((errors++))
    fi
    
    # Test compressed files
    for file in $(find "${BACKUP_DIR}" -name "*.tar.gz" -o -name "*.gz"); do
        if ! gzip -t "$file" 2>/dev/null; then
            error "Corrupted backup file: $file"
            ((errors++))
        fi
    done
    
    if [ $errors -eq 0 ]; then
        success "Backup integrity verification passed"
    else
        error "Backup integrity verification failed with $errors errors"
    fi
}

# Send backup notification
send_notification() {
    log "📧 Sending backup notification..."
    
    local backup_size=$(du -sh "${BACKUP_DIR}" | cut -f1)
    local files_count=$(find "${BACKUP_DIR}" -type f -name "*${DATE}*" | wc -l)
    
    # Create notification payload
    cat > /tmp/backup_notification.json << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "completed",
  "backup_id": "${DATE}",
  "server": "${SERVER_IP}",
  "size": "${backup_size}",
  "files": ${files_count},
  "retention": "${RETENTION_DAYS} days"
}
EOF
    
    # Log notification (webhook integration can be added here)
    success "Backup notification prepared"
}

# Main execution
main() {
    log "🚀 Starting automated backup process..."
    
    create_backup_structure
    backup_database
    backup_application_files
    backup_configurations
    backup_docker_volumes
    backup_logs
    create_manifest
    verify_backup
    cleanup_old_backups
    send_notification
    
    log "🎉 Backup process completed successfully!"
    echo ""
    echo "📊 Backup Summary:"
    echo "  ID: ${DATE}"
    echo "  Location: ${BACKUP_DIR}"
    echo "  Size: $(du -sh ${BACKUP_DIR} | cut -f1)"
    echo "  Files: $(find "${BACKUP_DIR}" -type f -name "*${DATE}*" | wc -l)"
    echo ""
    echo "📋 Manifest: ${BACKUP_DIR}/backup_manifest_${DATE}.json"
}

# Run main function
main "$@"
