#!/bin/bash

# Kodakclout – Automated Deployment Script
# Author: Damien (Kodakclout)
# Version: 1.1.2 (Robust Path & Node Detection)

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

log "Starting Kodakclout deployment..."

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
# Try to find node/npm in common paths
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

if ! command -v node &> /dev/null; then
    log "Node.js not found. Installing Node.js 20..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# Locate npm reliably
NPM_CMD=$(command -v npm || which npm || echo "")

# 4. pnpm & pm2 Setup
# Install pnpm if not present
if ! command -v pnpm &> /dev/null; then
    log "Installing pnpm..."
    # Try standalone installer first as it's more robust
    curl -fsSL https://get.pnpm.io/install.sh | ENV="$HOME/.bashrc" SHELL="$(command -v bash)" bash - || true
    
    # Add to current path for this session
    export PNPM_HOME="$HOME/.local/share/pnpm"
    export PATH="$PNPM_HOME:$PATH"
    
    # If still not found, try npm
    if ! command -v pnpm &> /dev/null && [ -n "$NPM_CMD" ]; then
        sudo "$NPM_CMD" install -g pnpm || npm install -g pnpm
    fi
fi

# Install PM2 if not present
if ! command -v pm2 &> /dev/null; then
    log "Installing PM2..."
    if [ -n "$NPM_CMD" ]; then
        sudo "$NPM_CMD" install -g pm2 || npm install -g pm2
    else
        # Last resort: try pnpm to install pm2
        pnpm add -g pm2 || true
    fi
fi

# Final check for critical tools
if ! command -v pnpm &> /dev/null; then error "pnpm could not be installed. Please install it manually."; fi
if ! command -v pm2 &> /dev/null; then error "pm2 could not be installed. Please install it manually."; fi

# 5. Setup Project
log "Setting up project dependencies..."
pnpm install

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
cd shared && pnpm build && cd ..

# 8. Database Migrations
log "Running database migrations..."
if grep -q "mysql://user:password" server/.env; then
    log "Skipping migrations: DATABASE_URL still has default placeholder."
else
    cd server && pnpm migrate && cd ..
fi

# 9. Build Frontend
log "Building frontend..."
cd client && pnpm build && cd ..

# 10. Build Backend
log "Building backend..."
cd server && pnpm build && cd ..

# 11. Start/Restart Application with PM2
log "Deploying with PM2..."
export NODE_ENV=production
PM2_CMD=$(command -v pm2)
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
