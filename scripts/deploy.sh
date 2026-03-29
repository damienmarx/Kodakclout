#!/bin/bash

# Kodakclout – Automated Deployment Script
# Author: Damien (Kodakclout)
# Version: 1.1.8 (Bulletproof Env & Self-Healing DB)

set -e

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Ensure we are in the project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

log "Starting Kodakclout deployment in $PROJECT_ROOT..."

# 1. Detect OS & Init System
OS_TYPE=$(lsb_release -is 2>/dev/null || echo "Unknown")
log "Detected OS: $OS_TYPE"

HAS_SYSTEMD=false
if pidof systemd >/dev/null 2>&1; then
    HAS_SYSTEMD=true
    log "Init system: systemd"
else
    log "Init system: SysVInit / Other (Non-systemd)"
fi

# 2. Install System Dependencies
log "Installing system dependencies..."
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -y
sudo apt-get install -y curl git mariadb-client build-essential psmisc net-tools jq

# 3. Node.js & npm Setup
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
if ! command -v node &> /dev/null; then
    log "Node.js not found. Installing Node.js 20..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi
NPM_CMD=$(command -v npm || which npm || echo "")

# 4. pnpm & pm2 Setup
if ! command -v pnpm &> /dev/null; then
    log "Installing pnpm..."
    curl -fsSL https://get.pnpm.io/install.sh | ENV="$HOME/.bashrc" SHELL="$(command -v bash)" bash - || true
    export PNPM_HOME="$HOME/.local/share/pnpm"
    export PATH="$PNPM_HOME:$PATH"
    if ! command -v pnpm &> /dev/null && [ -n "$NPM_CMD" ]; then
        sudo "$NPM_CMD" install -g pnpm || npm install -g pnpm
    fi
fi

if ! command -v pm2 &> /dev/null; then
    log "Installing PM2..."
    [ -n "$NPM_CMD" ] && (sudo "$NPM_CMD" install -g pm2 || npm install -g pm2) || pnpm add -g pm2 || true
    export PATH="$HOME/.local/share/pnpm:$PATH"
fi

# 5. Setup Project
log "Setting up project dependencies..."
pnpm install --no-frozen-lockfile

# 6. Handle Environment Files
log "Checking environment files..."
[ ! -f server/.env ] && cp server/.env.example server/.env && log "Created server/.env from template."
[ ! -f client/.env ] && cp client/.env.example client/.env && log "Created client/.env from template."

# ─── Bulletproof Env Loading ───
if [ -f server/.env ]; then
    log "Loading environment variables from server/.env..."
    # Export using a temporary file to avoid subshell issues and handle quotes/spaces
    TMP_ENV=$(mktemp)
    grep -v '^#' server/.env | grep '=' | sed 's/^/export /' > "$TMP_ENV"
    source "$TMP_ENV"
    rm "$TMP_ENV"
fi

# 7. Build Shared Module
log "Building shared module..."
(cd shared && pnpm build)

# 8. Database Initialization & Migrations
log "Handling database..."

# Check if DATABASE_URL is set after source
if [ -z "$DATABASE_URL" ]; then
    # Fallback: manually grep if source failed for some reason
    DATABASE_URL=$(grep "^DATABASE_URL=" server/.env | cut -d'=' -f2- | sed -e 's/^["'\'']//' -e 's/["'\'']$//')
    export DATABASE_URL
fi

if [ -z "$DATABASE_URL" ]; then
    error "DATABASE_URL is not set in server/.env. Please configure it."
fi

# Ensure MariaDB is running
if ! nc -z 127.0.0.1 3306; then
    log "MariaDB not reachable. Attempting to start..."
    if [ "$HAS_SYSTEMD" = true ]; then
        sudo systemctl start mariadb || sudo service mariadb start || true
    else
        sudo service mariadb start || sudo /etc/init.d/mariadb start || true
    fi
    sleep 5
fi

# Self-Healing: Try to create DB and User if connection fails
if ! mariadb -e "SELECT 1" >/dev/null 2>&1; then
    log "Default connection failed. Attempting self-healing as root..."
    sudo mariadb -u root <<EOF
CREATE DATABASE IF NOT EXISTS kodakclout;
CREATE USER IF NOT EXISTS 'clout_user'@'localhost' IDENTIFIED BY 'clout_pass';
GRANT ALL PRIVILEGES ON kodakclout.* TO 'clout_user'@'localhost';
FLUSH PRIVILEGES;
EOF
    success "Database and user 'clout_user' created/verified."
fi

# Update drizzle.config.json
sed -i "s|\"uri\": \".*\"|\"uri\": \"$DATABASE_URL\"|" server/drizzle.config.json

log "Running migrations..."
(cd server && pnpm migrate) || log "Migration failed. Continuing anyway..."

# 9. Build Frontend & Backend
log "Building frontend..."
(cd client && pnpm build)
log "Building backend..."
(cd server && pnpm build)

# 10. Cloudflare Tunnel Setup
log "Checking for Cloudflare Tunnel setup..."
# Ensure CLOUDFLARE_API_TOKEN is exported
[ -z "$CLOUDFLARE_API_TOKEN" ] && CLOUDFLARE_API_TOKEN=$(grep "^CLOUDFLARE_API_TOKEN=" server/.env | cut -d'=' -f2- | sed -e 's/^["'\'']//' -e 's/["'\'']$//')

if [ -n "$CLOUDFLARE_API_TOKEN" ]; then
    log "CLOUDFLARE_API_TOKEN found. Running Cloudflared setup..."
    export CLOUDFLARE_API_TOKEN
    chmod +x "$SCRIPT_DIR/setup-cloudflared.sh"
    "$SCRIPT_DIR/setup-cloudflared.sh"
else
    log "CLOUDFLARE_API_TOKEN not set. Skipping Cloudflared setup."
fi

# 11. Start Application with PM2
log "Deploying with PM2..."
export NODE_ENV=production
PM2_CMD=$(command -v pm2 || echo "pm2")
$PM2_CMD delete kodakclout 2>/dev/null || true
$PM2_CMD start server/dist/index.js --name kodakclout --update-env

# 12. Final Health Check
log "Validating deployment (waiting 10s)..."
sleep 10
if curl -sf http://127.0.0.1:8080/api/health | grep -q 'ok' || curl -sf http://localhost:8080/api/health | grep -q 'ok'; then
    success "Kodakclout is up and running!"
    log "Public URL: https://cloutscape.org"
else
    log "Health check failed. Showing last 30 lines of PM2 logs:"
    $PM2_CMD logs kodakclout --lines 30 --no-daemon &
    sleep 3
    kill $! 2>/dev/null || true
    error "Deployment failed. Check the logs above."
fi

success "Deployment complete."
