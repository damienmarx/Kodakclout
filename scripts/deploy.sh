#!/bin/bash

# Kodakclout – Automated Deployment Script
# Author: Damien (Kodakclout)
# Version: 1.1.1 (Improved Path Support)

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

# Install Node.js if not present
if ! command -v node &> /dev/null; then
    log "Installing Node.js 20..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# Ensure npm is available in the path for sudo
NPM_PATH=$(command -v npm || which npm || echo "/usr/bin/npm")

# Install pnpm if not present
if ! command -v pnpm &> /dev/null; then
    log "Installing pnpm..."
    # Use standalone script if npm fails
    curl -fsSL https://get.pnpm.io/install.sh | sh - || sudo "$NPM_PATH" install -g pnpm
fi

# Refresh path for pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"

# Install PM2 for process management
if ! command -v pm2 &> /dev/null; then
    log "Installing PM2..."
    sudo "$NPM_PATH" install -g pm2 || npm install -g pm2
fi

# 3. Setup Project
log "Setting up project dependencies..."
pnpm install

# 4. Handle Environment Files
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

# 5. Build Shared Module
log "Building shared module..."
cd shared && pnpm build && cd ..

# 6. Database Migrations
log "Running database migrations..."
if grep -q "mysql://user:password" server/.env; then
    log "Skipping migrations: DATABASE_URL still has default placeholder."
else
    cd server && pnpm migrate && cd ..
fi

# 7. Build Frontend
log "Building frontend..."
cd client && pnpm build && cd ..

# 8. Build Backend
log "Building backend..."
cd server && pnpm build && cd ..

# 9. Start/Restart Application with PM2
log "Deploying with PM2..."
export NODE_ENV=production
# Ensure pm2 is in path for the current user
PM2_PATH=$(command -v pm2 || which pm2 || echo "pm2")
$PM2_PATH delete kodakclout 2>/dev/null || true
$PM2_PATH start server/dist/index.js --name kodakclout --env production

# 10. Final Health Check
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
