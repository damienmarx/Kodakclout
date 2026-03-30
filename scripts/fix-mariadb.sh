#!/bin/bash
# Kodakclout – MariaDB Repair & Setup Script (Debian Optimized)
# Version: 1.0.1
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

log "Starting MariaDB Repair for Kodakclout..."

# 1. Ensure MariaDB is installed
if ! command -v mariadb &> /dev/null; then
    log "MariaDB not found. Installing..."
    sudo apt-get update && sudo apt-get install -y mariadb-server mariadb-client
fi

# 2. Force Start MariaDB Service
log "Ensuring MariaDB service is active..."
sudo systemctl start mariadb || sudo service mariadb start
sudo systemctl enable mariadb || true

# 3. Handle Unix Socket & Password Authentication
# Debian uses unix_socket by default for root. We need to create a user with a password for the app.
DB_NAME="kodakclout"
DB_USER="clout_user"
DB_PASS="clout_pass"

log "Configuring database and user (using sudo to bypass socket issues)..."
# We use sudo mariadb without -u root to use the unix_socket plugin for the root account.
sudo mariadb <<EOF
-- Create Database
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;

-- Create User (if not exists) and set password
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';

-- Update password (if user exists but password changed)
ALTER USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';

-- Grant Privileges
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';

-- Ensure the user doesn't use unix_socket (force password auth)
ALTER USER '${DB_USER}'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('${DB_PASS}');

FLUSH PRIVILEGES;
EOF

# 4. Final Verification
log "Verifying connectivity for ${DB_USER}..."
if mariadb -u "${DB_USER}" -p"${DB_PASS}" -e "USE ${DB_NAME}; SELECT 1;" &> /dev/null; then
    success "MariaDB is correctly configured and accessible!"
else
    error "Failed to connect to MariaDB even after repair. Check /var/log/mysql/error.log"
fi

success "MariaDB Repair Complete!"
