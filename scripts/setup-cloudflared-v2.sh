#!/bin/bash

# Kodakclout – Automated Cloudflared Tunnel Setup Script (V2)
# Author: Damien (Kodakclout)
# Version: 1.0.2 (Non-systemd Compatibility)

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

log "Starting Cloudflared Tunnel setup (V2)..."

# 1. Check for Cloudflare API Token
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    error "CLOUDFLARE_API_TOKEN environment variable is not set."
fi

# 2. Detect Init System
HAS_SYSTEMD=false
if pidof systemd >/dev/null 2>&1; then
    HAS_SYSTEMD=true
fi

# 3. Install cloudflared if not present
if ! command -v cloudflared &> /dev/null; then
    log "cloudflared not found. Installing..."
    curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared.deb
    rm cloudflared.deb
fi

# 4. Create Tunnel using API Token
log "Setting up Cloudflared tunnel..."

if [ "$HAS_SYSTEMD" = true ]; then
    log "Detected systemd. Creating systemd service..."
    sudo tee /etc/systemd/system/cloudflared-kodakclout.service > /dev/null <<EOF
[Unit]
Description=Cloudflare Tunnel for Kodakclout
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=/usr/bin/cloudflared tunnel run --token $CLOUDFLARE_API_TOKEN
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable cloudflared-kodakclout
    sudo systemctl restart cloudflared-kodakclout
else
    log "Non-systemd environment detected. Using PM2 to manage the tunnel..."
    PM2_CMD=$(command -v pm2 || echo "pm2")
    $PM2_CMD delete cloudflared-tunnel 2>/dev/null || true
    $PM2_CMD start "/usr/bin/cloudflared tunnel run --token $CLOUDFLARE_API_TOKEN" --name cloudflared-tunnel
    $PM2_CMD save
fi

success "Cloudflared tunnel is now running with your token."
log "Please ensure your Cloudflare Dashboard has 'cloutscape.org' pointing to this tunnel."
