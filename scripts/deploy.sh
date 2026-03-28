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
log "Detected OS: $OS_TYPE"

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
    # On Debian, the service name is usually 'mariadb'
    if ! sudo systemctl is-active --quiet mariadb; then
        log "MariaDB service is not running. Attempting to start..."
        sudo systemctl start mariadb || sudo service mariadb start || true
    fi
    
    if ! mariadb -e "SELECT 1" --connect-timeout=5 >/dev/null 2>&1; then
        log "WARNING: Local MariaDB connection failed. This is likely a permission issue."
        log "On Debian, the root user often uses unix_socket. Please run these commands manually:"
        log "----------------------------------------------------------------"
        log "sudo mariadb -u root -e \"CREATE DATABASE IF NOT EXISTS kodakclout;\""
        log "sudo mariadb -u root -e \"CREATE USER IF NOT EXISTS 'clout_user'@'localhost' IDENTIFIED BY 'clout_pass';\""
        log "sudo mariadb -u root -e \"GRANT ALL PRIVILEGES ON kodakclout.* TO 'clout_user'@'localhost';\""
        log "sudo mariadb -u root -e \"FLUSH PRIVILEGES;\""
        log "----------------------------------------------------------------"
        log "Then update your server/.env with: DATABASE_URL=mysql://clout_user:clout_pass@127.0.0.1:3306/kodakclout"
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
log "Checking for Cloudflare Tunnel setup..."
if [ -n "$CLOUDFLARE_API_TOKEN" ]; then
    log "CLOUDFLARE_API_TOKEN found. Running Cloudflared setup..."
    "$SCRIPT_DIR/setup-cloudflared.sh"
else
    log "CLOUDFLARE_API_TOKEN not set. Skipping Cloudflared setup."
fi

log "Deploying with PM2..."
export NODE_ENV=production
PM2_CMD=$(command -v pm2 || echo "pm2")
$PM2_CMD delete kodakclout 2>/dev/null || true
# Start with NODE_ENV=production so Express serves the frontend build
NODE_ENV=production $PM2_CMD start server/dist/index.js \
    --name kodakclout \
    --env production

# 12. Generate Nginx config (if nginx is installed)
if command -v nginx &> /dev/null; then
    log "Generating Nginx reverse-proxy config for cloutscape.org..."
    NGINX_CONF="/etc/nginx/sites-available/kodakclout"
    sudo tee "$NGINX_CONF" > /dev/null <<'NGINXEOF'
server {
    listen 80;
    server_name cloutscape.org www.cloutscape.org;

    # Redirect HTTP -> HTTPS (Cloudflare handles SSL, but this is a safety net)
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name cloutscape.org www.cloutscape.org;

    # Cloudflare Origin Certificates (place your cert/key here)
    ssl_certificate     /etc/nginx/ssl/cloutscape.crt;
    ssl_certificate_key /etc/nginx/ssl/cloutscape.key;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    # Proxy everything to the Node/Express server
    location / {
        proxy_pass         http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_set_header   Upgrade           $http_upgrade;
        proxy_set_header   Connection        "upgrade";
        proxy_read_timeout 60s;
    }
}
NGINXEOF
    sudo ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/kodakclout 2>/dev/null || true
    sudo nginx -t && sudo systemctl reload nginx || log "Nginx reload failed – check config manually."
    log "Nginx configured for cloutscape.org -> http://127.0.0.1:8080"
fi

# 13. Final Health Check
log "Validating deployment..."
sleep 5
if curl -sf http://localhost:8080/api/health | grep -q 'ok'; then
    success "Kodakclout is up and running!"
    log "Local URL:  http://localhost:8080"
    log "Public URL: https://cloutscape.org (via Cloudflare Tunnel if configured)"
    log "Frontend:   Served via Express at the same URL"
    log "Casino:     https://cloutscape.org/games"
else
    error "Health check failed. Check PM2 logs with: pm2 logs kodakclout"
fi

success "Deployment complete. Zero-input script finished successfully."
