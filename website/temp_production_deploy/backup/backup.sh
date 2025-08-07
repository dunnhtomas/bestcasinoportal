#!/bin/bash
set -e

# BestCasinoPortal Automated Backup System
# Creates daily backups of database, files, and configurations

BACKUP_DIR="/opt/backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30
LOG_FILE="/var/log/backup.log"

# Create backup directories
mkdir -p $BACKUP_DIR/database
mkdir -p $BACKUP_DIR/files
mkdir -p $BACKUP_DIR/configs

echo "$(date): Starting backup process" >> $LOG_FILE

# Database backup
echo "$(date): Backing up PostgreSQL database" >> $LOG_FILE
docker-compose exec -T postgres pg_dump -U casino_admin bestcasinoportal | gzip > $BACKUP_DIR/database/bestcasinoportal_$DATE.sql.gz

# Files backup
echo "$(date): Backing up website files" >> $LOG_FILE
tar -czf $BACKUP_DIR/files/website_$DATE.tar.gz -C /var/www bestcasinoportal.com

# Configuration backup
echo "$(date): Backing up configurations" >> $LOG_FILE
tar -czf $BACKUP_DIR/configs/configs_$DATE.tar.gz \
  /etc/nginx/sites-available/bestcasinoportal.com \
  /root/backend/docker-compose.yml \
  /root/backend/.env.production \
  /etc/letsencrypt/live/bestcasinoportal.com

# Redis backup
echo "$(date): Backing up Redis data" >> $LOG_FILE
docker-compose exec -T redis redis-cli SAVE
docker cp casino_redis:/data/dump.rdb $BACKUP_DIR/database/redis_$DATE.rdb

# Clean up old backups
echo "$(date): Cleaning up backups older than $RETENTION_DAYS days" >> $LOG_FILE
find $BACKUP_DIR -type f -mtime +$RETENTION_DAYS -delete

# Verify backup integrity
echo "$(date): Verifying backup integrity" >> $LOG_FILE
if [ -f "$BACKUP_DIR/database/bestcasinoportal_$DATE.sql.gz" ]; then
    gunzip -t "$BACKUP_DIR/database/bestcasinoportal_$DATE.sql.gz"
    if [ $? -eq 0 ]; then
        echo "$(date): Database backup verified successfully" >> $LOG_FILE
    else
        echo "$(date): ERROR: Database backup verification failed" >> $LOG_FILE
        exit 1
    fi
fi

# Calculate backup sizes
DATABASE_SIZE=$(du -sh $BACKUP_DIR/database/bestcasinoportal_$DATE.sql.gz | cut -f1)
FILES_SIZE=$(du -sh $BACKUP_DIR/files/website_$DATE.tar.gz | cut -f1)
CONFIG_SIZE=$(du -sh $BACKUP_DIR/configs/configs_$DATE.tar.gz | cut -f1)

echo "$(date): Backup completed successfully" >> $LOG_FILE
echo "$(date): Database: $DATABASE_SIZE, Files: $FILES_SIZE, Configs: $CONFIG_SIZE" >> $LOG_FILE

# Send backup notification (if email is configured)
if command -v mail >/dev/null 2>&1; then
    echo "BestCasinoPortal backup completed successfully on $(date)" | \
    mail -s "Backup Completed - $DATE" admin@bestcasinoportal.com
fi

echo "Backup process completed successfully"
