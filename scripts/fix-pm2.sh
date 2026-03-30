#!/bin/bash
# Kodakclout – PM2 Repair & Setup Script (Debian Optimized)
# Version: 1.0.1
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

log "Starting PM2 Repair for Kodakclout..."

# 1. Ensure PM2 is installed globally
if ! command -v pm2 &> /dev/null; then
    log "PM2 not found. Installing globally..."
    sudo npm install -g pm2
fi

# 2. Fix PM2 Permissions (Ensuring $USER can run it without sudo)
log "Fixing PM2 permissions for $USER..."
sudo chown -R $USER:$USER /home/$USER/.pm2 || true

# 3. Clear existing "ghost" processes
log "Cleaning up existing processes..."
pm2 delete all 2>/dev/null || true
pm2 kill || true

# 4. Re-initialize PM2 for current user
log "Re-initializing PM2..."
pm2 list > /dev/null

# 5. Configure PM2 Startup (Persistence)
log "Configuring PM2 startup for persistence..."
# Get the startup command from PM2 and execute it with sudo
STARTUP_CMD=$(pm2 startup systemd | grep "sudo env" || true)
if [ -n "$STARTUP_CMD" ]; then
    eval "$STARTUP_CMD"
fi

success "PM2 Repair Complete! Your user '$USER' can now manage processes safely."
