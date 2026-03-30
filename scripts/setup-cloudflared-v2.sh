#!/bin/bash
# Kodakclout – Adaptive Cloudflared Status & Repair Script (V2.1)
# Developed for damienmarx
# Version: 2.1.0 (Guaranteed Routing & Self-Healing)
set -e

# Colors for output
RED=\'\033[0;31m\'
GREEN=\'\033[0;32m\'
YELLOW=\'\033[1;33m\'
BLUE=\'\033[0;34m\'
NC=\'\033[0m\' # No Color

log() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Ensure environment variables are loaded from the correct location
if [ -f "../server/.env" ]; then
    export $(grep -v '^#' ../server/.env | xargs)
elif [ -f "server/.env" ]; then
    export $(grep -v '^#' server/.env | xargs)
fi

if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    error "CLOUDFLARE_API_TOKEN is not set in server/.env. Cannot proceed."
fi

DOMAIN="cloutscape.org"
TUNNEL_NAME="kodakclout-main-tunnel"

# 1. Check Cloudflared Installation
if ! command -v cloudflared &> /dev/null; then
    log "cloudflared not found. Installing..."
    curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared.deb
    rm cloudflared.deb
fi

# 2. Adaptive Status Check & Self-Healing
log "Checking Cloudflare Tunnel status for ${TUNNEL_NAME}..."

# Get Tunnel ID if it exists
TUNNEL_ID=$(cloudflared tunnel list --json | jq -r ".[] | select(.name == \"${TUNNEL_NAME}\") | .id")

if [ -z "$TUNNEL_ID" ]; then
    log "Tunnel '${TUNNEL_NAME}' not found. Creating new tunnel..."
    # Note: `cloudflared tunnel create` with a token is deprecated. Login is the modern way.
    # This script assumes a login has been performed or a cert.pem is available.
    TUNNEL_CREATE_OUTPUT=$(cloudflared tunnel create "${TUNNEL_NAME}")
    TUNNEL_ID=$(echo "$TUNNEL_CREATE_OUTPUT" | grep -oE '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}')
    success "Created new tunnel: ${TUNNEL_ID}"
else
    success "Found existing tunnel: ${TUNNEL_ID}"
fi

# 3. Guaranteed DNS Routing Check
log "Verifying DNS routes for ${DOMAIN}, api.${DOMAIN}, and games.${DOMAIN}..."

declare -a HOSTNAMES=("${DOMAIN}" "api.${DOMAIN}" "games.${DOMAIN}")
for hostname in "${HOSTNAMES[@]}"; do
    log "Checking route for ${hostname}..."
    # This command is idempotent and will create the route if it doesn't exist.
    cloudflared tunnel route dns "${TUNNEL_NAME}" "${hostname}"
done
success "DNS routes verified and/or created."

# 4. Adaptive Ingress Configuration
log "Updating ingress configuration for ${TUNNEL_ID}..."
sudo mkdir -p /etc/cloudflared
cat <<EOF | sudo tee /etc/cloudflared/config.yml > /dev/null
tunnel: ${TUNNEL_ID}
credentials-file: /home/$USER/.cloudflared/${TUNNEL_ID}.json
ingress:
  - hostname: ${DOMAIN}
    service: http://localhost:8080
  - hostname: api.${DOMAIN}
    service: http://localhost:8080
  - hostname: games.${DOMAIN}
    service: http://localhost:8081
  - service: http_status:404
EOF

# 5. Guaranteed Service Restart
log "Ensuring Cloudflared service is active and adaptive..."
# Stop any old service to avoid conflicts
sudo cloudflared service uninstall 2>/dev/null || true

if pidof systemd >/dev/null 2>&1; then
    log "Using systemd to manage Cloudflared service."
    sudo cloudflared --config /etc/cloudflared/config.yml service install
    sudo systemctl daemon-reload
    sudo systemctl enable cloudflared
    sudo systemctl restart cloudflared
else
    log "Using PM2 to manage Cloudflared service."
    PM2_CMD=$(command -v pm2 || echo "pm2")
    $PM2_CMD delete cloudflared 2>/dev/null || true
    $PM2_CMD start "cloudflared tunnel --config /etc/cloudflared/config.yml run" --name cloudflared
    $PM2_CMD save
fi

success "Cloudflared Adaptive Status Check & Repair complete!"
log "Your platform should now be accessible at: https://${DOMAIN}"
