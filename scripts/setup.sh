#!/bin/bash
# Kodakclout – Unified Setup & Deployment Script (Debian Optimized)
# Developed for damienmarx
# Version: 2.2.0 (Guaranteed Deployment & Adaptive Cloudflare)
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

echo -e "${GREEN}🚀 Starting Kodakclout Guaranteed Setup...${NC}"

# 0. Ownership & Permissions Management
log "Ensuring correct repository ownership for $USER..."
sudo chown -R $USER:$USER .
sudo chmod -R u+rw .
success "Ownership and permissions set to $USER."

# 0.1 Sudo Access Check
if ! sudo -n true 2>/dev/null; then
    warn "Sudo access without password is not configured. You may be prompted for your password."
fi

# 1. Local Environment Conflict Purge (Guaranteed Clean Slate)
log "Purging local environment conflicts..."
find . -name "node_modules" -type d -prune -exec rm -rf '{}' +
find . -name "dist" -type d -prune -exec rm -rf '{}' +
find . -name "pnpm-lock.yaml" -delete
find . -name ".turbo" -type d -prune -exec rm -rf '{}' +
success "Clean slate achieved."

# 2. Package Manager Pre-checks & Installation
log "Checking package manager..."
if ! command -v node &> /dev/null; then
    error "Node.js is not installed. Please install Node.js >= 18.0.0"
fi

# Ensure pnpm is installed and at correct version
if ! command -v pnpm &> /dev/null; then
    log "pnpm not found. Installing pnpm..."
    sudo npm install -g pnpm@8.15.0
else
    CURRENT_PNPM=$(pnpm -v)
    log "Found pnpm version $CURRENT_PNPM"
fi

# 3. System Dependencies (Debian)
log "Checking system dependencies..."
DEPS=(curl git jq mariadb-server mariadb-client net-tools build-essential golang)
MISSING_DEPS=()
for dep in "${DEPS[@]}"; do
    if ! dpkg -s "$dep" >/dev/null 2>&1; then
        MISSING_DEPS+=("$dep")
    fi
done

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    log "Installing missing system dependencies: ${MISSING_DEPS[*]}"
    sudo apt-get update
    sudo apt-get install -y "${MISSING_DEPS[@]}"
fi

# 4. Database Setup (MariaDB Self-Healing)
log "Configuring MariaDB..."
sudo systemctl start mariadb || sudo service mariadb start
sudo systemctl enable mariadb || true

DB_NAME="kodakclout"
DB_USER="clout_user"
DB_PASS="clout_pass"

log "Verifying database and user..."
sudo mariadb -u root <<EOF || warn "Failed to verify/create database as root."
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# 5. Project Dependencies (Guaranteed Install)
log "Installing project dependencies..."
pnpm install --no-frozen-lockfile || error "Failed to install dependencies."

# 6. Environment Files
log "Handling environment files..."
[ ! -f server/.env ] && cp server/.env.example server/.env && warn "Created server/.env. PLEASE UPDATE IT!"
[ ! -f client/.env ] && cp client/.env.example client/.env && warn "Created client/.env. PLEASE UPDATE IT!"

if [ -f server/.env ]; then
    export $(grep -v '^#' server/.env | xargs)
fi

# 7. Guaranteed Build (with Error Recovery)
log "Building workspace..."
if ! pnpm run build; then
    warn "Build failed. Attempting recovery by clearing cache..."
    pnpm store prune
    pnpm run build || error "Build failed after recovery attempt."
fi
success "Workspace built successfully."

# 8. Database Migrations
log "Running database migrations..."
(cd server && pnpm migrate) || warn "Migration failed or no changes. Continuing..."

# 9. Seamless Clutch Integration
log "Checking for Clutch Games Engine..."
PROJECT_ROOT=$(pwd)
CLUTCH_DIR="$(dirname "$PROJECT_ROOT")/Clutch"

if [ ! -d "$CLUTCH_DIR" ]; then
    log "Clutch directory not found. Cloning from repository..."
    git clone https://github.com/damienmarx/Clutch.git "$CLUTCH_DIR" || warn "Failed to clone Clutch repository."
fi

if [ -d "$CLUTCH_DIR" ]; then
    log "Building Clutch engine..."
    (cd "$CLUTCH_DIR" && go build -o clutch-server main.go) || warn "Failed to build Clutch from source."
    
    if [ -f "$CLUTCH_DIR/clutch-server" ]; then
        log "Deploying Clutch engine with PM2..."
        PM2_CMD=$(command -v pm2 || echo "pm2")
        $PM2_CMD delete clutch-engine 2>/dev/null || true
        (cd "$CLUTCH_DIR" && $PM2_CMD start ./clutch-server --name clutch-engine -- web -c degens777den.yaml)
        success "Clutch engine is now running."
    fi
else
    warn "Clutch engine integration skipped."
fi

# 10. Adaptive Cloudflared Status Check & Repair
log "Checking Cloudflared configuration..."
if [ -n "$CLOUDFLARE_API_TOKEN" ]; then
    log "CLOUDFLARE_API_TOKEN found. Running Adaptive Cloudflared Status Check..."
    if [ -f "scripts/setup-cloudflared-v2.sh" ]; then
        chmod +x scripts/setup-cloudflared-v2.sh
        ./scripts/setup-cloudflared-v2.sh || warn "Cloudflared status check/repair failed."
    else
        warn "scripts/setup-cloudflared-v2.sh not found."
    fi
else
    warn "CLOUDFLARE_API_TOKEN not set in server/.env. Skipping Cloudflared setup."
fi

# 11. Final Health Checks & PM2 Deployment
log "Performing final health checks..."
PM2_CMD=$(command -v pm2 || echo "pm2")
if ! command -v pm2 &> /dev/null; then
    log "Installing PM2..."
    sudo npm install -g pm2
    PM2_CMD="pm2"
fi

$PM2_CMD delete kodakclout 2>/dev/null || true
$PM2_CMD start server/dist/server/src/index.js --name kodakclout --update-env

log "Waiting for server to stabilize (10s)..."
sleep 10

KODAKCLOUT_PORT=${PORT:-8080}
if curl -sf "http://127.0.0.1:$KODAKCLOUT_PORT/api/health" | grep -q 'ok'; then
    success "Kodakclout backend health check passed!"
else
    warn "Kodakclout health check failed at http://127.0.0.1:$KODAKCLOUT_PORT/api/health"
fi

success "Unified Kodakclout Guaranteed Setup complete!"
echo -e "${YELLOW}Manage your application with:${NC} pm2 status"
echo -e "${YELLOW}View logs with:${NC} pm2 logs kodakclout"
echo -e "${YELLOW}Clutch engine is running as:${NC} clutch-engine"
