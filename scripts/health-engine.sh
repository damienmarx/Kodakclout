#!/bin/bash
set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
API_URL="http://localhost:8080/api/health"
LOG_FILE="/var/log/kodakclout-health.log"

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }

# ─── Health Check Logic ──────────────────────────────────────────────────────
check_health() {
    if curl -s --head --request GET "$API_URL" | grep "200 OK" > /dev/null; then
        return 0
    else
        return 1
    fi
}

# ─── Self-Healing Logic ──────────────────────────────────────────────────────
heal() {
    log "CRITICAL: Health check failed. Initiating self-healing..."
    pm2 restart kodakclout || pm2 start server/dist/server/src/index.js --name kodakclout
    
    if check_health; then
        log "SUCCESS: Engine recovered."
    else
        log "FAILURE: Engine recovery failed. Restarting Nginx..."
        systemctl restart nginx
    fi
}

# ─── Main Loop ───────────────────────────────────────────────────────────────
if check_health; then
    log "STATUS: Engine healthy."
else
    heal
fi
