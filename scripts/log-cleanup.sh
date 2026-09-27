#!/usr/bin/env bash
#
# log-cleanup.sh
# Cleans up Docker logs, dangling images, and old system logs to
# prevent EC2 disk space exhaustion. Intended to run daily via cron.
#
# Usage:  ./log-cleanup.sh
# Cron:   30 3 * * *  /opt/devops-capstone/scripts/log-cleanup.sh >> /var/log/capstone-cleanup.log 2>&1

set -euo pipefail

MAX_LOG_SIZE_MB=100
DAYS_TO_KEEP=14

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

log "Starting cleanup routine..."

# 1. Truncate oversized Docker container JSON logs
if command -v docker >/dev/null 2>&1; then
    for container in $(docker ps -q); do
        log_path=$(docker inspect --format='{{.LogPath}}' "$container" 2>/dev/null || true)
        if [ -n "$log_path" ] && [ -f "$log_path" ]; then
            size_mb=$(du -m "$log_path" | cut -f1)
            if [ "$size_mb" -gt "$MAX_LOG_SIZE_MB" ]; then
                log "Truncating oversized log (${size_mb}MB): $log_path"
                : > "$log_path"
            fi
        fi
    done

    # 2. Remove dangling images, stopped containers, unused networks
    log "Pruning unused Docker resources..."
    docker system prune -f --filter "until=${DAYS_TO_KEEP}h" >/dev/null 2>&1 || true
fi

# 3. Clean up old application logs on the host (if written outside Docker)
APP_LOG_DIR="/var/log/devops-capstone-app"
if [ -d "$APP_LOG_DIR" ]; then
    log "Removing app logs older than ${DAYS_TO_KEEP} days from ${APP_LOG_DIR}"
    find "$APP_LOG_DIR" -type f -name "*.log" -mtime "+${DAYS_TO_KEEP}" -print -delete
fi

# 4. Clean up old journal logs (systemd)
if command -v journalctl >/dev/null 2>&1; then
    log "Vacuuming systemd journal logs older than ${DAYS_TO_KEEP} days..."
    sudo journalctl --vacuum-time="${DAYS_TO_KEEP}d" || true
fi

log "Cleanup complete."
