#!/bin/bash

# Kodakclout – Automated Cloudflared Tunnel Setup Script
# Author: Damien (Kodakclout)
# Version: 2.0.0

set -e

# Colors for logging
RED=\'\\033[0;31m\'
GREEN=\'\\033[0;32m\'
BLUE=\'\\033[0;34m\'
NC=\'\\033[0m\' # No Color

log() {
    echo -e "${BLUE}[$(date +\'%Y-%m-%d %H:%M:%S\')]${NC} $1"
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

log "Starting Cloudflared Tunnel setup..."

# 1. Load environment variables from server/.env
if [ -f "server/.env" ]; then
    log "Loading environment variables from server/.env"
    export $(grep -v \'^#\' server/.env | xargs)
else
    error "server/.env file not found. Please create it with CLOUDFLARE_API_TOKEN."
fi

# 2. Check for Cloudflare API Token
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    error "CLOUDFLARE_API_TOKEN environment variable is not set in server/.env. Please set it."
fi

# 3. Install cloudflared
if ! command -v cloudflared &> /dev/null; then
    log "cloudflared not found. Installing cloudflared..."
    curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared.deb
    rm cloudflared.deb
    log "cloudflared installed."
else
    log "cloudflared is already installed."
fi

# 4. Define tunnel names and hostnames
KODAKCLOUT_TUNNEL_NAME="kodakclout-main-tunnel"
CLUTCH_TUNNEL_NAME="clutch-games-tunnel"
DOMAIN="cloutscape.org"

# 5. Setup Kodakclout Tunnel
log "Setting up Kodakclout Main Tunnel: ${KODAKCLOUT_TUNNEL_NAME}"
KODAKCLOUT_TUNNEL_ID=$(cloudflared tunnel list --json | jq -r ".[] | select(.name == \"${KODAKCLOUT_TUNNEL_NAME}\") | .id")

if [ -z "$KODAKCLOUT_TUNNEL_ID" ]; then
    log "Creating new Kodakclout tunnel: ${KODAKCLOUT_TUNNEL_NAME}"
    TUNNEL_CREATE_OUTPUT=$(cloudflared tunnel create "${KODAKCLOUT_TUNNEL_NAME}" --token "$CLOUDFLARE_API_TOKEN" --output-json)
    KODAKCLOUT_TUNNEL_ID=$(echo "$TUNNEL_CREATE_OUTPUT" | jq -r ".id")
    log "Kodakclout Tunnel created with ID: ${KODAKCLOUT_TUNNEL_ID}"
else
    log "Kodakclout Tunnel \'${KODAKCLOUT_TUNNEL_NAME}\' (ID: ${KODAKCLOUT_TUNNEL_ID}) already exists."
fi

# Configure Kodakclout tunnel ingress
KODAKCLOUT_CONFIG_PATH="/etc/cloudflared/${KODAKCLOUT_TUNNEL_ID}.json"
cat <<EOF | sudo tee /etc/cloudflared/config-${KODAKCLOUT_TUNNEL_NAME}.yaml > /dev/null
tunnel: ${KODAKCLOUT_TUNNEL_ID}
credentials-file: ${KODAKCLOUT_CONFIG_PATH}

ingress:
  - hostname: ${DOMAIN}
    service: http://localhost:8080
  - hostname: api.${DOMAIN}
    service: http://localhost:8080
  - service: http_status:404
EOF
success "Kodakclout tunnel configuration updated."

# Create DNS records for Kodakclout tunnel
log "Creating DNS records for ${KODAKCLOUT_TUNNEL_NAME}..."
cloudflared tunnel route dns "${KODAKCLOUT_TUNNEL_NAME}" "${DOMAIN}" || true # Ignore errors if already exists
cloudflared tunnel route dns "${KODAKCLOUT_TUNNEL_NAME}" "api.${DOMAIN}" || true # Ignore errors if already exists
success "DNS records for Kodakclout tunnel created/updated."

# 6. Setup Clutch Tunnel
log "Setting up Clutch Games Tunnel: ${CLUTCH_TUNNEL_NAME}"
CLUTCH_TUNNEL_ID=$(cloudflared tunnel list --json | jq -r ".[] | select(.name == \"${CLUTCH_TUNNEL_NAME}\") | .id")

if [ -z "$CLUTCH_TUNNEL_ID" ]; then
    log "Creating new Clutch tunnel: ${CLUTCH_TUNNEL_NAME}"
    TUNNEL_CREATE_OUTPUT=$(cloudflared tunnel create "${CLUTCH_TUNNEL_NAME}" --token "$CLOUDFLARE_API_TOKEN" --output-json)
    CLUTCH_TUNNEL_ID=$(echo "$TUNNEL_CREATE_OUTPUT" | jq -r ".id")
    log "Clutch Tunnel created with ID: ${CLUTCH_TUNNEL_ID}"
else
    log "Clutch Tunnel \'${CLUTCH_TUNNEL_NAME}\' (ID: ${CLUTCH_TUNNEL_ID}) already exists."
fi

# Configure Clutch tunnel ingress
CLUTCH_CONFIG_PATH="/etc/cloudflared/${CLUTCH_TUNNEL_ID}.json"
cat <<EOF | sudo tee /etc/cloudflared/config-${CLUTCH_TUNNEL_NAME}.yaml > /dev/null
tunnel: ${CLUTCH_TUNNEL_ID}
credentials-file: ${CLUTCH_CONFIG_PATH}

ingress:
  - hostname: games.${DOMAIN}
    service: http://localhost:8081
  - service: http_status:404
EOF
success "Clutch tunnel configuration updated."

# Create DNS records for Clutch tunnel
log "Creating DNS records for ${CLUTCH_TUNNEL_NAME}..."
cloudflared tunnel route dns "${CLUTCH_TUNNEL_NAME}" "games.${DOMAIN}" || true # Ignore errors if already exists
success "DNS records for Clutch tunnel created/updated."

# 7. Install and run as systemd services
log "Installing Cloudflared tunnels as systemd services..."

# Kodakclout Tunnel Service
sudo cloudflared --config /etc/cloudflared/config-${KODAKCLOUT_TUNNEL_NAME}.yaml service install "${KODAKCLOUT_TUNNEL_NAME}"
sudo systemctl enable "cloudflared@${KODAKCLOUT_TUNNEL_NAME}"
sudo systemctl start "cloudflared@${KODAKCLOUT_TUNNEL_NAME}"

# Clutch Tunnel Service
sudo cloudflared --config /etc/cloudflared/config-${CLUTCH_TUNNEL_NAME}.yaml service install "${CLUTCH_TUNNEL_NAME}"
sudo systemctl enable "cloudflared@${CLUTCH_TUNNEL_NAME}"
sudo systemctl start "cloudflared@${CLUTCH_TUNNEL_NAME}"

success "Cloudflared tunnel services installed and started."

log "Cloudflared tunnel setup complete. Your sites should now be accessible via Cloudflare:"
log "- https://${DOMAIN}"
log "- https://api.${DOMAIN}"
log "- https://games.${DOMAIN}"
log "Please ensure your domain's nameservers are pointed to Cloudflare."
