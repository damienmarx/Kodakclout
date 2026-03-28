#!/bin/bash

# Kodakclout – Automated Cloudflared Tunnel Setup Script
# Author: Damien (Kodakclout)
# Version: 1.0.0

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

log "Starting Cloudflared Tunnel setup..."

# 1. Check for Cloudflare API Token
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    error "CLOUDFLARE_API_TOKEN environment variable is not set. Please set it before running this script."
fi

# 2. Install cloudflared
if ! command -v cloudflared &> /dev/null; then
    log "cloudflared not found. Installing cloudflared..."
    curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared.deb
    rm cloudflared.deb
    log "cloudflared installed."
else
    log "cloudflared is already installed."
fi

# 3. Authenticate cloudflared
log "Authenticating cloudflared with Cloudflare..."
# This command will use the CLOUDFLARE_API_TOKEN to authenticate
# and create a ~/.cloudflared/cert.pem file.
cloudflared tunnel login --token "$CLOUDFLARE_API_TOKEN" || error "Cloudflared login failed. Check your CLOUDFLARE_API_TOKEN."
success "cloudflared authenticated."

# 4. Create a named tunnel (if it doesn't exist)
TUNNEL_NAME="kodakclout-tunnel"
TUNNEL_ID=$(cloudflared tunnel list --json | jq -r ".[] | select(.name == \"$TUNNEL_NAME\") | .id")

if [ -z "$TUNNEL_ID" ]; then
    log "Creating new Cloudflared tunnel: $TUNNEL_NAME..."
    TUNNEL_CREATE_OUTPUT=$(cloudflared tunnel create "$TUNNEL_NAME" --output-json)
    TUNNEL_ID=$(echo "$TUNNEL_CREATE_OUTPUT" | jq -r ".id")
    TUNNEL_SECRET=$(echo "$TUNNEL_CREATE_OUTPUT" | jq -r ".secret")
    log "Tunnel created with ID: $TUNNEL_ID"
    log "Tunnel secret saved to ~/.cloudflared/$TUNNEL_ID.json"
else
    log "Cloudflared tunnel '$TUNNEL_NAME' (ID: $TUNNEL_ID) already exists."
fi

# 5. Configure the tunnel
log "Configuring tunnel to proxy to localhost:8080..."
CONFIG_PATH="~/.cloudflared/$TUNNEL_ID.json"

# Create or update the config.yml file
cat <<EOF > ~/.cloudflared/config.yml
tunnel: $TUNNEL_ID
credentials-file: $CONFIG_PATH

ingress:
  - hostname: cloutscape.org
    service: http://localhost:8080
  - hostname: www.cloutscape.org
    service: http://localhost:8080
  - service: http_status:404
EOF

success "Tunnel configuration updated."

# 6. Create DNS records (if they don't exist)
log "Creating DNS records for cloutscape.org and www.cloutscape.org..."
# This step requires Cloudflare API key to be set up in cloudflared login
# or manually via Cloudflare API. For simplicity, we assume the login step handles this.
# Alternatively, the user can manually create CNAME records in Cloudflare DNS dashboard:
# CNAME cloutscape.org -> <TUNNEL_ID>.cfargotunnel.com
# CNAME www -> <TUNNEL_ID>.cfargotunnel.com

# Note: cloudflared tunnel run --url http://localhost:8080 can create temporary DNS records
# but for persistent tunnels, it's better to manage them via the Cloudflare dashboard
# or use `cloudflared tunnel route dns <TUNNEL_NAME> <HOSTNAME>`

# For automated DNS record creation, we'd need Cloudflare API key and Zone ID.
# Given the current setup, we'll instruct the user to do this manually or ensure the token has DNS permissions.

# For now, let's assume the user will manually create the CNAME records.
log "Please ensure you have CNAME records in your Cloudflare DNS for cloutscape.org and www.cloutscape.org"
log "pointing to $TUNNEL_ID.cfargotunnel.com."

# 7. Install and run as a systemd service
log "Installing Cloudflared tunnel as a systemd service..."
sudo cloudflared --config ~/.cloudflared/config.yml service install
sudo systemctl enable cloudflared
sudo systemctl start cloudflared

success "Cloudflared tunnel service installed and started."

log "Cloudflared tunnel setup complete. Your site should now be accessible via Cloudflare."
log "Remember to create CNAME records in your Cloudflare DNS for cloutscape.org and www.cloutscape.org"
log "pointing to $TUNNEL_ID.cfargotunnel.com."
