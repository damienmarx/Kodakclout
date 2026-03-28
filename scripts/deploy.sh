#!/bin/bash

# Kodakclout – Automated Deployment Script
# Author: Damien (Kodakclout)
# Version: 1.1.3 (Fix Path & Migration Issues)

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

# 1. Detect OS
OS_TYPE=$(lsb_release -is 2>/dev/null || echo "Unknown")
if [[ "$OS_TYPE" != "Ubuntu" && "$OS_TYPE" != "Debian" ]]; then
    log "Warning: This script is optimized for Ubuntu/Debian. Proceeding anyway..."
fi

# 2. Install System Dependencies (Non-interactive)
log "Installing system dependencies..."
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -y
sudo apt-get install -y curl git mariadb-client build-essential psmisc

# 3. Node.js & npm Setup
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

if ! command -v node &> /dev/null; then
    log "Node.js not found. Installing Node.js 20..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# Locate npm reliably
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
    if [ -n "$NPM_CMD" ]; then
        sudo "$NPM_CMD" install -g pm2 || npm install -g pm2
    else
        pnpm add -g pm2 || true
    fi
    export PATH="$HOME/.local/share/pnpm:$PATH"
fi

# 5. Setup Project
log "Setting up project dependencies..."
# Use --yes to skip interactive prompts for node_modules removal
pnpm install --no-frozen-lockfile

# 6. Handle Environment Files
log "Checking environment files..."
if [ ! -f server/.env ]; then
    log "Creating default server/.env from template..."
    cp server/.env.example server/.env
    log "WARNING: Please update server/.env with real credentials."
fi

if [ ! -f client/.env ]; then
    log "Creating default client/.env from template..."
    cp client/.env.example client/.env
fi

# 7. Build Shared Module
log "Building shared module..."
(cd shared && pnpm build)

# 8. Database Migrations
log "Running database migrations..."
if grep -q "mysql://user:password" server/.env; then
    log "Skipping migrations: DATABASE_URL still has default placeholder."
else
    # Update drizzle.config.json with the actual DATABASE_URL from .env
    DB_URL=$(grep "DATABASE_URL=" server/.env | cut -d'=' -f2-)
    if [ -n "$DB_URL" ]; then
        sed -i "s|\"uri\": \".*\"|\"uri\": \"$DB_URL\"|" server/drizzle.config.json
    fi
    
    log "Testing database connection..."
    if ! mariadb -e "SELECT 1" --connect-timeout=5 >/dev/null 2>&1; then
        log "WARNING: Local MariaDB connection failed. Ensure MariaDB is running and the database exists."
        log "You may need to run: sudo systemctl start mariadb"
        log "And: mariadb -u root -e 'CREATE DATABASE IF NOT EXISTS kodakclout;'"
    fi
    
    (cd server && pnpm migrate) || log "Migration failed. Please check your DATABASE_URL in server/.env"
fi

# 9. Build Frontend
log "Building frontend..."
(cd client && pnpm build)

# 10. Build Backend
log "Building backend..."
(cd server && pnpm build)

# 11. Start/Restart Application with PM2
log "Deploying with PM2..."
export NODE_ENV=production
PM2_CMD=$(command -v pm2 || echo "pm2")
$PM2_CMD delete kodakclout 2>/dev/null || true
$PM2_CMD start server/dist/index.js --name kodakclout --env production

# 12. Final Health Check
log "Validating deployment..."
sleep 5
if curl -s http://localhost:8080/api/games > /dev/null; then
    success "Kodakclout is up and running!"
    log "Local URL: http://localhost:8080"
    log "Public URL: https://cloutscape.org"
    log "Frontend: Served via backend at the same URL"
else
    error "Health check failed. Check PM2 logs with 'pm2 logs kodakclout'"
fi

success "Deployment complete. Zero-input script finished successfully."
