#!/bin/bash
# Kodakclout – MariaDB Universal Repair Script (Debian Optimized)
# Version: 1.1.0 (Non-systemd & Zero-Password Root Support)
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

log "Starting MariaDB Universal Repair..."

# 1. Detect Init System & Force Start
if pidof systemd >/dev/null 2>&1; then
    log "Detected systemd. Starting MariaDB..."
    sudo systemctl start mariadb || sudo systemctl restart mariadb
else
    log "Non-systemd environment detected. Using SysV service..."
    sudo service mariadb start || sudo /etc/init.d/mariadb start
fi

# 2. MariaDB Root Access Recovery (Guaranteed)
DB_NAME="kodakclout"
DB_USER="clout_user"
DB_PASS="clout_pass"

log "Configuring database and user (Adaptive Root Access)..."

# Try multiple ways to access root MariaDB (Socket first, then no-password)
# We use sudo to leverage the unix_socket plugin which is default on Debian root.
if sudo mariadb -e "SELECT 1;" &> /dev/null; then
    SQL_CMD="sudo mariadb"
elif sudo mysql -e "SELECT 1;" &> /dev/null; then
    SQL_CMD="sudo mysql"
else
    warn "Direct root access failed. Attempting password-less recovery mode..."
    # If root access is totally blocked, we can't easily fix it without manual intervention
    # but we'll try one last 'empty password' attempt.
    SQL_CMD="sudo mariadb -u root"
fi

$SQL_CMD <<EOF || error "Failed to execute SQL commands as root. Please check MariaDB root permissions."
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
ALTER USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
-- Force native password authentication for the app user
ALTER USER '${DB_USER}'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('${DB_PASS}');
FLUSH PRIVILEGES;
EOF

# 3. Final Verification
log "Verifying connectivity for ${DB_USER}..."
if mariadb -u "${DB_USER}" -p"${DB_PASS}" -e "USE ${DB_NAME}; SELECT 1;" &> /dev/null; then
    success "MariaDB is correctly configured and accessible!"
else
    error "Failed to connect to MariaDB even after repair. Check /var/log/mysql/error.log"
fi

success "MariaDB Universal Repair Complete!"
