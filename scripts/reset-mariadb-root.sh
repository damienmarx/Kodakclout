#!/bin/bash
# Kodakclout – MariaDB Root Password Reset & Env Sync Script
# Version: 1.0.0 (Guaranteed Access Recovery)
set -e

# Environment Isolation
export PATH=$(echo $PATH | tr ':' '\n' | grep -v "/mnt/c/" | tr '\n' ':' | sed 's/:$//')
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games:$PATH"

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

# Determine Project Root
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$SCRIPT_PATH" == */scripts ]]; then
    PROJECT_ROOT="$(dirname "$SCRIPT_PATH")"
else
    PROJECT_ROOT="$SCRIPT_PATH"
fi
cd "$PROJECT_ROOT"

NEW_ROOT_PASS="KODAKCLOUT_ROOT_2026"
DB_NAME="kodakclout"
DB_USER="clout_user"
DB_PASS="clout_pass"

log "Starting MariaDB Root Password Reset (Guaranteed Recovery)..."

# 1. Stop MariaDB Service
log "Stopping MariaDB service..."
if pidof systemd >/dev/null 2>&1; then
    sudo systemctl stop mariadb || sudo systemctl kill -s SIGKILL mariadb || true
else
    sudo service mariadb stop || sudo pkill -9 mysqld || true
fi

# 2. Start MariaDB in Safe Mode (Skip Grant Tables)
log "Starting MariaDB in Safe Mode (skipping permissions check)..."
sudo mysqld_safe --skip-grant-tables --skip-networking &
SAFE_PID=$!

# Wait for MariaDB to start
log "Waiting for MariaDB to initialize (10s)..."
sleep 10

# 3. Reset Root Password & Setup App User
log "Resetting root password and setting up app user..."
mariadb -u root <<EOF
FLUSH PRIVILEGES;
-- Reset root password
ALTER USER 'root'@'localhost' IDENTIFIED BY '${NEW_ROOT_PASS}';
-- Ensure root doesn't use unix_socket
ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('${NEW_ROOT_PASS}');

-- Setup App User (clout_user)
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
ALTER USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
ALTER USER '${DB_USER}'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('${DB_PASS}');

FLUSH PRIVILEGES;
EOF

# 4. Stop Safe Mode & Restart Normally
log "Restarting MariaDB normally..."
sudo pkill -9 mysqld || true
sleep 5

if pidof systemd >/dev/null 2>&1; then
    sudo systemctl start mariadb
else
    sudo service mariadb start
fi

# 5. Update server/.env
log "Updating server/.env with new database credentials..."
if [ -f "server/.env" ]; then
    # Replace existing DATABASE_URL line
    sed -i "s|DATABASE_URL=.*|DATABASE_URL=\"mysql://${DB_USER}:${DB_PASS}@localhost:3306/${DB_NAME}\"|" server/.env
    success "server/.env updated with guaranteed credentials."
else
    warn "server/.env not found. Skipping env update."
fi

# 6. Final Verification
log "Verifying connectivity for ${DB_USER}..."
if mariadb -u "${DB_USER}" -p"${DB_PASS}" -e "USE ${DB_NAME}; SELECT 1;" &> /dev/null; then
    success "MariaDB is correctly configured and accessible!"
    echo -e "${GREEN}========================================${NC}"
    echo -e "${YELLOW}MariaDB ROOT Password:${NC} ${NEW_ROOT_PASS}"
    echo -e "${YELLOW}App User (clout_user) Password:${NC} ${DB_PASS}"
    echo -e "${GREEN}========================================${NC}"
else
    error "Failed to connect even after reset. Check /var/log/mysql/error.log"
fi

success "MariaDB Reset & Env Sync Complete!"
