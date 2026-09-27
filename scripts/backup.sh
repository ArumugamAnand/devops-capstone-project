#!/usr/bin/env bash
#
# backup.sh
# Backs up application logs/data and Docker container logs, compresses them,
# and prunes backups older than RETENTION_DAYS. Intended to run via cron
# on the App EC2 instance.
#
# Usage:  ./backup.sh
# Cron:   0 2 * * *  /opt/devops-capstone/scripts/backup.sh >> /var/log/capstone-backup.log 2>&1

set -euo pipefail

# ---- Configuration ----
APP_NAME="devops-capstone-app"
BACKUP_DIR="/opt/backups/${APP_NAME}"
SOURCE_LOG_DIR="/var/log/${APP_NAME}"          # adjust to wherever app logs live
RETENTION_DAYS=7
TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"
BACKUP_FILE="${BACKUP_DIR}/backup_${TIMESTAMP}.tar.gz"

# Optional: set S3_BUCKET to also upload backups to S3 (requires AWS CLI configured)
S3_BUCKET="${S3_BUCKET:-}"

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

mkdir -p "$BACKUP_DIR"

log "Starting backup for ${APP_NAME}..."

# 1. Collect Docker container logs
if command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' | grep -q "^${APP_NAME}$"; then
    mkdir -p "/tmp/${APP_NAME}_backup_tmp"
    docker logs "${APP_NAME}" > "/tmp/${APP_NAME}_backup_tmp/container.log" 2>&1 || true
else
    log "Warning: container ${APP_NAME} not running, skipping container log capture."
fi

# 2. Include any app log/data directory if present
if [ -d "$SOURCE_LOG_DIR" ]; then
    cp -r "$SOURCE_LOG_DIR" "/tmp/${APP_NAME}_backup_tmp/app_logs" 2>/dev/null || true
fi

# 3. Compress everything into one archive
if [ -d "/tmp/${APP_NAME}_backup_tmp" ]; then
    tar -czf "$BACKUP_FILE" -C "/tmp/${APP_NAME}_backup_tmp" .
    rm -rf "/tmp/${APP_NAME}_backup_tmp"
    log "Backup created: ${BACKUP_FILE} ($(du -h "$BACKUP_FILE" | cut -f1))"
else
    log "Nothing to back up."
    exit 0
fi

# 4. Optional upload to S3
if [ -n "$S3_BUCKET" ] && command -v aws >/dev/null 2>&1; then
    log "Uploading backup to s3://${S3_BUCKET}/backups/"
    aws s3 cp "$BACKUP_FILE" "s3://${S3_BUCKET}/backups/$(basename "$BACKUP_FILE")"
fi

# 5. Prune old local backups
log "Removing backups older than ${RETENTION_DAYS} days..."
find "$BACKUP_DIR" -name "backup_*.tar.gz" -type f -mtime "+${RETENTION_DAYS}" -print -delete

log "Backup complete."
