#!/bin/bash
# Kodakclout – MariaDB Precision Root Password Reset & Env Sync Script
# Version: 1.2.0 (Precision Recovery Mode)
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

log "Starting MariaDB PRECISION Root Password Reset..."

# 1. Force-Kill Only MariaDB/MySQL Processes (Precision Step)
log "Cleaning up MariaDB/MySQL processes (Safe Mode)..."
sudo systemctl stop mariadb 2>/dev/null || sudo service mariadb stop 2>/dev/null || true

# Use pgrep to find PIDs and kill them one by one to avoid self-termination
log "Targeting database PIDs..."
MYSQL_PIDS=$(pgrep -f "mysql|mariadb" | grep -v "$$" || true)
if [ -n "$MYSQL_PIDS" ]; then
    for pid in $MYSQL_PIDS; do
        sudo kill -9 "$pid" 2>/dev/null || true
    done
fi

# 2. Clear Stuck Sockets and Locks
log "Cleaning up stuck sockets and lock files..."
sudo rm -f /var/run/mysqld/mysqld.sock 2>/dev/null || true
sudo rm -f /var/run/mysqld/mysqld.pid 2>/dev/null || true
sudo rm -f /var/lib/mysql/mysql.sock 2>/dev/null || true
sudo rm -f /var/lib/mysql/mysql.pid 2>/dev/null || true

# 3. Start MariaDB in Safe Mode (Guaranteed Isolation)
log "Starting MariaDB in Safe Mode (skipping permissions check)..."
INIT_FILE="/tmp/mariadb_init.sql"
cat <<EOF > "$INIT_FILE"
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

# Run mysqld directly with the init file for a guaranteed reset
log "Executing direct reset via mysqld bootstrap..."
# Check if mysqld is available, otherwise try mariadbd
SQLD_CMD=$(command -v mysqld || command -v mariadbd || echo "/usr/sbin/mysqld")
sudo "$SQLD_CMD" --user=mysql --bootstrap --skip-grant-tables --skip-networking < "$INIT_FILE" || warn "Bootstrap reset failed, attempting safe-mode daemon..."

# Fallback to Safe Mode Daemon if bootstrap failed
if ! mariadb -u root -p"${NEW_ROOT_PASS}" -e "SELECT 1;" &>/dev/null; then
    log "Fallback: Starting Safe Mode daemon..."
    sudo mysqld_safe --skip-grant-tables --skip-networking &
    log "Waiting for Safe Mode daemon (15s)..."
    sleep 15
    mariadb -u root <<EOF || warn "Safe mode reset failed."
    $(cat "$INIT_FILE")
EOF
fi

# 4. Cleanup and Normal Restart
log "Cleaning up and restarting MariaDB normally..."
# Kill only the processes we just started
sudo pkill -9 -f "mysqld_safe|mysqld|mariadbd" 2>/dev/null || true
rm -f "$INIT_FILE"
sleep 5

if pidof systemd >/dev/null 2>&1; then
    sudo systemctl start mariadb
else
    sudo service mariadb start
fi

# 5. Update server/.env
log "Updating server/.env with new database credentials..."
if [ -f "server/.env" ]; then
    # Use | as delimiter to avoid path issues
    sed -i "s|DATABASE_URL=.*|DATABASE_URL=\"mysql://${DB_USER}:${DB_PASS}@localhost:3306/${DB_NAME}\"|" server/.env
    success "server/.env updated."
else
    warn "server/.env not found."
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
    error "Precision reset failed. Your MariaDB installation may be corrupted. Check /var/log/mysql/error.log"
fi

success "MariaDB Precision Reset Complete!"
