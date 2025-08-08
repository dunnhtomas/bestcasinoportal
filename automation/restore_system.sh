#!/bin/bash

# 🔄 Best Casino Portal - Backup Restore System
# Professional Recovery & Disaster Recovery Solution

set -euo pipefail

# Configuration
BACKUP_DIR="/opt/casino-backups"
RESTORE_DATE=""
DRY_RUN=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Usage function
usage() {
    cat << EOF
🔄 Casino Portal Backup Restore System

Usage: $0 [OPTIONS]

Options:
    -d, --date DATE         Backup date to restore (format: YYYYMMDD_HHMMSS)
    -l, --list             List available backups
    -n, --dry-run          Show what would be restored without actually doing it
    -h, --help             Show this help message

Examples:
    $0 --list                           # List all available backups
    $0 --date 20250808_143000          # Restore specific backup
    $0 --date 20250808_143000 --dry-run # Preview restore operation

EOF
}

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅${NC} $1"
}

error() {
    echo -e "${RED}❌${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

# List available backups
list_backups() {
    log "📋 Available backups:"
    echo ""
    
    if [ ! -d "$BACKUP_DIR" ]; then
        warning "No backup directory found at $BACKUP_DIR"
        exit 1
    fi
    
    local manifests=$(find "$BACKUP_DIR" -name "backup_manifest_*.json" | sort -r)
    
    if [ -z "$manifests" ]; then
        warning "No backup manifests found"
        exit 1
    fi
    
    printf "%-20s %-15s %-10s %-8s\n" "BACKUP ID" "DATE" "SIZE" "FILES"
    printf "%-20s %-15s %-10s %-8s\n" "--------" "----" "----" "-----"
    
    for manifest in $manifests; do
        local backup_id=$(basename "$manifest" | sed 's/backup_manifest_\(.*\)\.json/\1/')
        local backup_date=$(jq -r '.backup_date' "$manifest" 2>/dev/null || echo "Unknown")
        local backup_size=$(jq -r '.backup_size' "$manifest" 2>/dev/null || echo "Unknown")
        local files_count=$(jq -r '.files_count' "$manifest" 2>/dev/null || echo "Unknown")
        
        printf "%-20s %-15s %-10s %-8s\n" "$backup_id" "$backup_date" "$backup_size" "$files_count"
    done
    
    echo ""
}

# Validate backup exists
validate_backup() {
    local date="$1"
    
    if [ ! -f "${BACKUP_DIR}/backup_manifest_${date}.json" ]; then
        error "Backup manifest not found for date: $date"
    fi
    
    log "📋 Validating backup: $date"
    
    # Check manifest integrity
    if ! jq empty "${BACKUP_DIR}/backup_manifest_${date}.json" 2>/dev/null; then
        error "Invalid backup manifest format"
    fi
    
    success "Backup validation passed"
}

# Restore database
restore_database() {
    local date="$1"
    
    log "🗄️ Restoring database..."
    
    if [ "$DRY_RUN" = true ]; then
        log "🔍 DRY RUN: Would restore database from backup $date"
        return
    fi
    
    # Stop applications that use the database
    systemctl stop casino-api 2>/dev/null || true
    systemctl stop casino-analytics 2>/dev/null || true
    
    # Restore PostgreSQL
    if [ -f "${BACKUP_DIR}/database/${date}/casino_database_${date}.sql.gz" ]; then
        log "Restoring PostgreSQL database..."
        
        # Create backup of current database
        PGPASSWORD="casino_secure_password_2025" pg_dump -h localhost -U casino_admin -d bestcasinoportal \
            > "/tmp/current_db_backup_$(date +%Y%m%d_%H%M%S).sql" 2>/dev/null || true
        
        # Restore from backup
        gunzip -c "${BACKUP_DIR}/database/${date}/casino_database_${date}.sql.gz" | \
            PGPASSWORD="casino_secure_password_2025" psql -h localhost -U casino_admin -d bestcasinoportal
        
        success "PostgreSQL database restored"
    fi
    
    # Restore Redis
    if [ -f "${BACKUP_DIR}/database/${date}/redis_${date}.rdb" ]; then
        log "Restoring Redis data..."
        
        systemctl stop redis-server
        cp "${BACKUP_DIR}/database/${date}/redis_${date}.rdb" /var/lib/redis/dump.rdb
        chown redis:redis /var/lib/redis/dump.rdb
        systemctl start redis-server
        
        success "Redis data restored"
    fi
    
    # Restart applications
    systemctl start casino-api 2>/dev/null || true
    systemctl start casino-analytics 2>/dev/null || true
}

# Restore application files
restore_files() {
    local date="$1"
    
    log "�� Restoring application files..."
    
    if [ "$DRY_RUN" = true ]; then
        log "🔍 DRY RUN: Would restore application files from backup $date"
        return
    fi
    
    # Stop services
    systemctl stop nginx 2>/dev/null || true
    
    # Restore website files
    if [ -f "${BACKUP_DIR}/files/${date}/website_files_${date}.tar.gz" ]; then
        log "Restoring website files..."
        
        # Backup current files
        if [ -d "/var/www/bestcasinoportal.com" ]; then
            mv "/var/www/bestcasinoportal.com" "/var/www/bestcasinoportal.com.backup.$(date +%Y%m%d_%H%M%S)"
        fi
        
        # Extract backup
        tar -xzf "${BACKUP_DIR}/files/${date}/website_files_${date}.tar.gz" -C /var/www/
        chown -R www-data:www-data /var/www/bestcasinoportal.com
        
        success "Website files restored"
    fi
    
    # Restore API files
    if [ -f "${BACKUP_DIR}/files/${date}/api_files_${date}.tar.gz" ]; then
        log "Restoring API files..."
        
        if [ -d "/opt/casino-api" ]; then
            mv "/opt/casino-api" "/opt/casino-api.backup.$(date +%Y%m%d_%H%M%S)"
        fi
        
        tar -xzf "${BACKUP_DIR}/files/${date}/api_files_${date}.tar.gz" -C /opt/
        
        success "API files restored"
    fi
    
    # Restart services
    systemctl start nginx 2>/dev/null || true
}

# Restore configurations
restore_configs() {
    local date="$1"
    
    log "⚙️ Restoring configurations..."
    
    if [ "$DRY_RUN" = true ]; then
        log "🔍 DRY RUN: Would restore configurations from backup $date"
        return
    fi
    
    # Restore Nginx configuration
    if [ -f "${BACKUP_DIR}/configs/${date}/nginx_config_${date}.tar.gz" ]; then
        log "Restoring Nginx configuration..."
        
        # Backup current config
        tar -czf "/tmp/nginx_config_backup_$(date +%Y%m%d_%H%M%S).tar.gz" -C /etc nginx
        
        # Restore from backup
        tar -xzf "${BACKUP_DIR}/configs/${date}/nginx_config_${date}.tar.gz" -C /etc/
        
        # Test configuration
        if nginx -t; then
            systemctl reload nginx
            success "Nginx configuration restored"
        else
            error "Nginx configuration test failed - please check manually"
        fi
    fi
    
    # Restore SSL certificates
    if [ -f "${BACKUP_DIR}/configs/${date}/ssl_certs_${date}.tar.gz" ]; then
        log "Restoring SSL certificates..."
        
        tar -czf "/tmp/ssl_certs_backup_$(date +%Y%m%d_%H%M%S).tar.gz" -C /etc letsencrypt 2>/dev/null || true
        tar -xzf "${BACKUP_DIR}/configs/${date}/ssl_certs_${date}.tar.gz" -C /etc/
        
        success "SSL certificates restored"
    fi
}

# Restore Docker volumes
restore_docker_volumes() {
    local date="$1"
    
    log "🐳 Restoring Docker volumes..."
    
    if [ "$DRY_RUN" = true ]; then
        log "🔍 DRY RUN: Would restore Docker volumes from backup $date"
        return
    fi
    
    # Stop monitoring stack
    docker-compose -f /opt/casino-monitoring/docker-compose.yml down 2>/dev/null || true
    
    # Restore Prometheus data
    if [ -f "${BACKUP_DIR}/files/${date}/prometheus_data_${date}.tar.gz" ]; then
        log "Restoring Prometheus data..."
        
        docker volume rm casino-monitoring_prometheus_data 2>/dev/null || true
        docker volume create casino-monitoring_prometheus_data
        
        # Extract to temporary location and copy to volume
        mkdir -p /tmp/prometheus_restore
        tar -xzf "${BACKUP_DIR}/files/${date}/prometheus_data_${date}.tar.gz" -C /tmp/prometheus_restore
        
        # Copy data to volume (requires running container)
        docker run --rm -v casino-monitoring_prometheus_data:/data -v /tmp/prometheus_restore:/backup alpine \
            sh -c "cp -r /backup/casino-monitoring_prometheus_data/_data/* /data/"
        
        rm -rf /tmp/prometheus_restore
        success "Prometheus data restored"
    fi
    
    # Restore Grafana data
    if [ -f "${BACKUP_DIR}/files/${date}/grafana_data_${date}.tar.gz" ]; then
        log "Restoring Grafana data..."
        
        docker volume rm casino-monitoring_grafana_data 2>/dev/null || true
        docker volume create casino-monitoring_grafana_data
        
        mkdir -p /tmp/grafana_restore
        tar -xzf "${BACKUP_DIR}/files/${date}/grafana_data_${date}.tar.gz" -C /tmp/grafana_restore
        
        docker run --rm -v casino-monitoring_grafana_data:/data -v /tmp/grafana_restore:/backup alpine \
            sh -c "cp -r /backup/casino-monitoring_grafana_data/_data/* /data/ && chown -R 472:472 /data"
        
        rm -rf /tmp/grafana_restore
        success "Grafana data restored"
    fi
    
    # Start monitoring stack
    docker-compose -f /opt/casino-monitoring/docker-compose.yml up -d 2>/dev/null || true
}

# Verify restore
verify_restore() {
    log "🔍 Verifying restore operation..."
    
    local errors=0
    
    # Check website
    if ! curl -s http://localhost > /dev/null; then
        warning "Website not responding"
        ((errors++))
    fi
    
    # Check API
    if ! curl -s http://localhost:4000/health > /dev/null; then
        warning "Main API not responding"
        ((errors++))
    fi
    
    # Check database
    if ! PGPASSWORD="casino_secure_password_2025" psql -h localhost -U casino_admin -d bestcasinoportal -c "SELECT 1;" > /dev/null 2>&1; then
        warning "Database connection failed"
        ((errors++))
    fi
    
    # Check monitoring
    if ! curl -s http://localhost:9090/-/healthy > /dev/null; then
        warning "Prometheus not responding"
        ((errors++))
    fi
    
    if [ $errors -eq 0 ]; then
        success "Restore verification passed"
    else
        warning "Restore verification completed with $errors warnings"
    fi
}

# Main restore function
perform_restore() {
    local date="$1"
    
    log "🔄 Starting restore process for backup: $date"
    
    validate_backup "$date"
    
    if [ "$DRY_RUN" = false ]; then
        read -p "⚠️  This will overwrite current data. Continue? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            log "Restore cancelled by user"
            exit 0
        fi
    fi
    
    restore_database "$date"
    restore_files "$date"
    restore_configs "$date"
    restore_docker_volumes "$date"
    
    if [ "$DRY_RUN" = false ]; then
        verify_restore
        success "🎉 Restore completed successfully!"
    else
        success "🔍 Dry run completed - no changes made"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--date)
            RESTORE_DATE="$2"
            shift 2
            ;;
        -l|--list)
            list_backups
            exit 0
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Main execution
if [ -z "$RESTORE_DATE" ]; then
    usage
    exit 1
fi

perform_restore "$RESTORE_DATE"
