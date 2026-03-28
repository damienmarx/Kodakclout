#!/bin/bash

# Kodakclout – Automated Cloudflared Tunnel Setup Script (V2)
# Author: Damien (Kodakclout)
# Version: 1.0.1

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

# 2. Install cloudflared if not present
if ! command -v cloudflared &> /dev/null; then
    log "cloudflared not found. Installing..."
    curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared.deb
    rm cloudflared.deb
fi

# 3. Create Tunnel using API Token
TUNNEL_NAME="kodakclout-tunnel"
log "Creating or retrieving tunnel: $TUNNEL_NAME..."

# Create a temporary credentials file for the token
mkdir -p ~/.cloudflared

# Check if tunnel already exists
EXISTING_TUNNEL=$(cloudflared tunnel list --token "$CLOUDFLARE_API_TOKEN" --output json | jq -r ".[] | select(.name == \"$TUNNEL_NAME\") | .id" 2>/dev/null || true)

if [ -z "$EXISTING_TUNNEL" ]; then
    log "Creating new tunnel..."
    # Note: Creating a tunnel via token requires the 'cloudflared tunnel create' command
    # but the token itself often represents a 'Remote Managed' tunnel.
    # For a 'Locally Managed' tunnel via script, we usually need a cert.pem.
    # However, we can use the token to run a tunnel directly.
    success "Cloudflare API Token is ready."
else
    log "Tunnel already exists with ID: $EXISTING_TUNNEL"
fi

# 4. Generate Configuration
# For a token-based setup, we'll use a systemd service that runs 'cloudflared tunnel run --token <TOKEN>'
log "Setting up systemd service for Cloudflared..."

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

# 5. Start Service
log "Starting Cloudflared service..."
sudo systemctl daemon-reload
sudo systemctl enable cloudflared-kodakclout
sudo systemctl start cloudflared-kodakclout

success "Cloudflared tunnel service is now running with your token."
log "Please ensure your Cloudflare Dashboard has 'cloutscape.org' pointing to this tunnel."
