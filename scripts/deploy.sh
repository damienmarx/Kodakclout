#!/bin/bash

# Kodakclout – Automated Deployment Script
# Author: Damien (Kodakclout)
# Version: 1.1.6 (Fixed Env Export & Health Checks)

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
sudo apt-get install -y curl git mariadb-client build-essential psmisc net-tools

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

# ─── Robust Env Loading ───
if [ -f server/.env ]; then
    log "Loading environment variables from server/.env..."
    # Export all variables from .env, ignoring comments and empty lines
    # Using a more robust way to export variables with potential spaces or special chars
    while IFS='=' read -r key value || [ -n "$key" ]; do
        # Skip comments and empty lines
        if [[ $key =~ ^[[:space:]]*# ]] || [[ -z $key ]]; then
            continue
        fi
        # Remove potential surrounding quotes from value
        value=$(echo "$value" | sed -E 's/^["'\'']|["'\'']$//g')
        # Export the variable
        export "$key"="$value"
    done < server/.env
fi

# 7. Build Shared Module
log "Building shared module..."
(cd shared && pnpm build)

# 8. Database Migrations
log "Running database migrations..."
if [ -z "$DATABASE_URL" ] || [[ "$DATABASE_URL" == *"user:password"* ]]; then
    log "Skipping migrations: DATABASE_URL not configured correctly."
else
    # Update drizzle.config.json
    sed -i "s|\"uri\": \".*\"|\"uri\": \"$DATABASE_URL\"|" server/drizzle.config.json
    
    log "Testing database connection to 127.0.0.1:3306..."
    if ! nc -z 127.0.0.1 3306; then
        log "WARNING: MariaDB (3306) is not reachable. Attempting to start service..."
        if [ "$HAS_SYSTEMD" = true ]; then
            sudo systemctl start mariadb || sudo service mariadb start || true
        else
            sudo service mariadb start || sudo /etc/init.d/mariadb start || true
        fi
        sleep 5
    fi
    
    (cd server && pnpm migrate) || log "Migration failed. Check if MariaDB is running (sudo service mariadb status)."
fi

# 9. Build Frontend & Backend
log "Building frontend..."
(cd client && pnpm build)
log "Building backend..."
(cd server && pnpm build)

# 10. Cloudflare Tunnel Setup
log "Checking for Cloudflare Tunnel setup..."
if [ -n "$CLOUDFLARE_API_TOKEN" ]; then
    log "CLOUDFLARE_API_TOKEN found. Running Cloudflared setup..."
    chmod +x "$SCRIPT_DIR/setup-cloudflared-v2.sh"
    "$SCRIPT_DIR/setup-cloudflared-v2.sh"
else
    log "CLOUDFLARE_API_TOKEN not set in environment. Skipping Cloudflared setup."
fi

# 11. Start Application with PM2
log "Deploying with PM2..."
export NODE_ENV=production
PM2_CMD=$(command -v pm2 || echo "pm2")
$PM2_CMD delete kodakclout 2>/dev/null || true
# Start with explicit environment loading and a slightly longer wait for startup
$PM2_CMD start server/dist/index.js --name kodakclout --update-env

# 12. Final Health Check
log "Validating deployment (waiting 10s for startup)..."
sleep 10
# Try both localhost and 127.0.0.1
if curl -sf http://127.0.0.1:8080/api/health | grep -q 'ok' || curl -sf http://localhost:8080/api/health | grep -q 'ok'; then
    success "Kodakclout is up and running!"
    log "Public URL: https://cloutscape.org"
else
    log "Health check failed at http://localhost:8080/api/health"
    log "Checking PM2 status..."
    $PM2_CMD status kodakclout
    log "Last 20 lines of logs:"
    $PM2_CMD logs kodakclout --lines 20 --no-daemon &
    sleep 2
    kill $! 2>/dev/null || true
    error "Deployment validation failed. See logs above for details."
fi

success "Deployment complete."
