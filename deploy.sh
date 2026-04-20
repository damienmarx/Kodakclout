#!/bin/bash
set -euo pipefail

# ─── Colors ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date +'%T')]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# ─── Configuration ───────────────────────────────────────────────────────────
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_USER="kodakclout"
DB_NAME="kodakclout"
DB_USER="kodakclout"
DB_PASS="maria"

log "Starting Kodakclout Professional Deployment..."

# 1. System Check
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
fi

# 2. Install Dependencies
log "Installing system dependencies..."
apt-get update -qq
apt-get install -y -qq curl git build-essential mariadb-server nginx psmisc > /dev/null

# 3. Install Node.js & pnpm
if ! command -v node &> /dev/null; then
    log "Installing Node.js 22..."
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - > /dev/null
    apt-get install -y -qq nodejs > /dev/null
fi

if ! command -v pnpm &> /dev/null; then
    log "Installing pnpm..."
    npm install -g pnpm > /dev/null
fi

if ! command -v pm2 &> /dev/null; then
    log "Installing PM2..."
    npm install -g pm2 > /dev/null
fi

# 4. Database Setup
log "Configuring MariaDB..."
systemctl start mariadb
mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# 5. Application Setup
log "Building application..."
cd "$PROJECT_DIR"
pnpm install --frozen-lockfile > /dev/null
pnpm build > /dev/null

# 6. Environment Configuration
if [ ! -f .env ]; then
    log "Generating .env file..."
    JWT_SECRET=$(openssl rand -base64 32)
    cat > .env <<EOF
DATABASE_URL=mysql://$DB_USER:$DB_PASS@localhost:3306/$DB_NAME
PORT=8080
NODE_ENV=production
JWT_SECRET=$JWT_SECRET
PASSWORD_SALT_ROUNDS=12
CLUTCH_API_URL=http://localhost:8081
CLUTCH_API_KEY=local-clutch-key
EOF
fi

# 7. Database Migration
log "Running migrations..."
pnpm --filter @kodakclout/server run migrate

# 8. PM2 Process Management
log "Starting application with PM2..."
pm2 delete kodakclout 2>/dev/null || true
pm2 start server/dist/server/src/index.js --name kodakclout --env production

# 9. Nginx Configuration
log "Configuring Nginx..."
cat > /etc/nginx/sites-available/kodakclout <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

ln -sf /etc/nginx/sites-available/kodakclout /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx

success "Kodakclout is now LIVE at http://$(curl -s ifconfig.me)"
success "Deployment complete. No errors found."
