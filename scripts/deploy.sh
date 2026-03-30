#!/bin/bash

# Kodakclout – Automated Deployment Script
# Author: Damien (Kodakclout)
# Version: 2.3.0 (Unified & Hardened Deployment)

set -e

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
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
cd "$PROJECT_ROOT" || error "Failed to change to project root directory."

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
sudo apt-get update -y || warn "Apt update failed. Continuing anyway..."
sudo apt-get install -y curl git mariadb-client build-essential psmisc net-tools jq || error "Failed to install system dependencies."

# 3. Go 1.25+ Setup (Required for Clutch)
log "Checking Go version..."
GO_VERSION_REQUIRED="1.25.0"
CURRENT_GO_VERSION=$(go version 2>/dev/null | awk '{print $3}' | sed 's/go//')

if [ -z "$CURRENT_GO_VERSION" ] || [ "$(printf '%s\n' "$GO_VERSION_REQUIRED" "$CURRENT_GO_VERSION" | sort -V | head -n1)" != "$GO_VERSION_REQUIRED" ]; then
    log "Go $GO_VERSION_REQUIRED+ not found (Current: ${CURRENT_GO_VERSION:-None}). Installing Go $GO_VERSION_REQUIRED..."
    GO_TAR="go${GO_VERSION_REQUIRED}.linux-amd64.tar.gz"
    curl -LO "https://go.dev/dl/$GO_TAR" || error "Failed to download Go $GO_VERSION_REQUIRED."
    sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf "$GO_TAR" || error "Failed to install Go."
    rm "$GO_TAR"
    export PATH="/usr/local/go/bin:$PATH"
    echo 'export PATH="/usr/local/go/bin:$PATH"' >> "$HOME/.bashrc"
    success "Go $GO_VERSION_REQUIRED installed successfully."
else
    success "Go version $CURRENT_GO_VERSION is sufficient."
fi

# 4. Node.js & npm Setup
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
if ! command -v node &> /dev/null; then
    log "Node.js not found. Installing Node.js 20..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - || error "Failed to add Node.js repository."
    sudo apt-get install -y nodejs || error "Failed to install Node.js."
fi
NPM_CMD=$(command -v npm || which npm || echo "")

# 5. pnpm & pm2 Setup
if ! command -v pnpm &> /dev/null; then
    log "Installing pnpm..."
    curl -fsSL https://get.pnpm.io/install.sh | ENV="$HOME/.bashrc" SHELL="$(command -v bash)" bash - || true
    export PNPM_HOME="$HOME/.local/share/pnpm"
    export PATH="$PNPM_HOME:$PATH"
    if ! command -v pnpm &> /dev/null && [ -n "$NPM_CMD" ]; then
        sudo "$NPM_CMD" install -g pnpm || npm install -g pnpm || error "Failed to install pnpm globally."
    fi
fi

if ! command -v pm2 &> /dev/null; then
    log "Installing PM2..."
    [ -n "$NPM_CMD" ] && (sudo "$NPM_CMD" install -g pm2 || npm install -g pm2) || pnpm add -g pm2 || error "Failed to install PM2 globally."
    export PATH="$HOME/.local/share/pnpm:$PATH"
fi

# 6. Setup Project
log "Setting up project dependencies..."
pnpm install --no-frozen-lockfile || error "Failed to install project dependencies."

# 7. Handle Environment Files
log "Checking environment files..."
[ ! -f server/.env ] && cp server/.env.example server/.env && warn "Created server/.env from template. PLEASE UPDATE IT!"
[ ! -f client/.env ] && cp client/.env.example client/.env && warn "Created client/.env from template. PLEASE UPDATE IT!"

# ─── Bulletproof Env Loading ───
if [ -f server/.env ]; then
    log "Loading environment variables from server/.env..."
    while IFS='=' read -r key value || [ -n "$key" ]; do
        [[ $key =~ ^#.* ]] && continue
        [[ -z $key ]] && continue
        value=$(echo "$value" | sed -e 's/^["'\'']//' -e 's/["'\'']$//')
        export "$key"="$value"
    done < server/.env
else
    error "server/.env file not found. Cannot proceed."
fi

# 8. Build Shared Module
log "Building shared module..."
(cd shared && pnpm build) || error "Failed to build shared module."

# 9. Database Initialization & Migrations
log "Handling database..."

if [ -z "$DATABASE_URL" ]; then
    error "DATABASE_URL is not set in server/.env. Please configure it."
fi

# Ensure MariaDB is running
if ! nc -z 127.0.0.1 3306; then
    log "MariaDB not reachable on 3306. Attempting to start..."
    if [ "$HAS_SYSTEMD" = true ]; then
        sudo systemctl start mariadb || sudo service mariadb start || warn "Failed to start MariaDB."
    else
        sudo service mariadb start || sudo /etc/init.d/mariadb start || warn "Failed to start MariaDB."
    fi
    sleep 5
fi

# Self-Healing: Try to create DB and User
if ! mariadb -e "SELECT 1" >/dev/null 2>&1; then
    log "Default MariaDB connection failed. Attempting self-healing as root..."
    DB_NAME=$(echo "$DATABASE_URL" | sed -n 's/.*\/\([^?]*\).*/\1/p')
    [ -z "$DB_NAME" ] && DB_NAME="kodakclout"
    
    sudo mariadb -u root <<EOF || warn "Failed to verify/create database as root."
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS 'clout_user'@'localhost' IDENTIFIED BY 'clout_pass';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO 'clout_user'@'localhost';
FLUSH PRIVILEGES;
EOF
    success "Database verification complete."
fi

# Update drizzle.config.json if it exists
if [ -f server/drizzle.config.json ]; then
    sed -i "s|\"uri\": \".*\"|\"uri\": \"$DATABASE_URL\"|" server/drizzle.config.json || warn "Failed to update drizzle.config.json."
fi

log "Running migrations..."
(cd server && pnpm migrate) || warn "Migration failed or no changes. Continuing..."

# 10. Build Frontend & Backend
log "Building frontend..."
(cd client && pnpm build) || error "Failed to build frontend."
log "Building backend..."
(cd server && pnpm build) || error "Failed to build backend."

# 11. Cloudflare Tunnel Setup
log "Checking for Cloudflare Tunnel setup..."
if [ -n "$CLOUDFLARE_API_TOKEN" ]; then
    log "CLOUDFLARE_API_TOKEN found. Running Cloudflared setup..."
    if [ -f "$SCRIPT_DIR/setup-cloudflared.sh" ]; then
        chmod +x "$SCRIPT_DIR/setup-cloudflared.sh"
        "$SCRIPT_DIR/setup-cloudflared.sh" || warn "Cloudflared setup script failed."
    else
        warn "setup-cloudflared.sh not found."
    fi
fi

# 12. Start Kodakclout Application with PM2
log "Deploying Kodakclout with PM2..."
export NODE_ENV=production
PM2_CMD=$(command -v pm2 || echo "pm2")
$PM2_CMD delete kodakclout 2>/dev/null || true
$PM2_CMD start server/dist/index.js --name kodakclout --update-env || error "Failed to start Kodakclout with PM2."

# 13. Build and Start Clutch Backend
log "Checking for Clutch backend..."
CLUTCH_DIR="$(dirname "$PROJECT_ROOT")"/Clutch
CLUTCH_CONFIG="$CLUTCH_DIR/degens777den.yaml"

if [ -d "$CLUTCH_DIR" ] && [ -f "$CLUTCH_CONFIG" ]; then
    log "Building Clutch backend from source..."
    (cd "$CLUTCH_DIR" && go build -o clutch-server main.go) || warn "Failed to build Clutch from source."
    
    if [ -f "$CLUTCH_DIR/clutch-server" ]; then
        log "Deploying Clutch backend with PM2..."
        chmod +x "$CLUTCH_DIR/clutch-server"
        $PM2_CMD delete clutch-engine 2>/dev/null || true
        # Start Clutch from its directory so it can find its local assets
        (cd "$CLUTCH_DIR" && $PM2_CMD start ./clutch-server --name clutch-engine -- web -c "$CLUTCH_CONFIG") || warn "Failed to start Clutch with PM2."
        success "Clutch backend deployment attempted."
    else
        warn "Clutch server binary not found after build attempt."
    fi
else
    warn "Clutch directory or config not found at $CLUTCH_DIR. Skipping Clutch deployment."
fi

# 14. Final Health Checks
log "Validating deployments (waiting 10s)..."
sleep 10

KODAKCLOUT_PORT=${PORT:-8080}
if curl -sf "http://127.0.0.1:$KODAKCLOUT_PORT/api/health" | grep -q 'ok'; then
    success "Kodakclout backend health check passed!"
else
    warn "Kodakclout health check failed at http://127.0.0.1:$KODAKCLOUT_PORT/api/health"
fi

success "Unified deployment script finished."
