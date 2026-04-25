#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration Variables --------------------------------------------------
USER="damien"
HOME_DIR="/home/${USER}"
REPO_DIR="${HOME_DIR}/Kodakclout"
CLUTCH_DIR="${HOME_DIR}/Clutch"
CLUTCH_ENGINE_PATH="${REPO_DIR}/Clutch/clutch-server"

DB_USER="clout_user"
DB_PASS="clout_pass"
DB_NAME="kodakclout"

CLUTCH_API_KEY="slotopol_secret_key_12345" # Pre-filled for slotopol engine
JWT_SECRET="kodakclout_prod_secret_998877" # Pre-filled production secret

# --- Logging Functions --------------------------------------------------------
log() { echo -e "\e[34m[INFO]\e[0m $1"; }
success() { echo -e "\e[32m[SUCCESS]\e[0m $1"; }
warn() { echo -e "\e[33m[WARN]\e[0m $1"; }
error() { echo -e "\e[31m[ERROR]\e[0m $1" >&2; exit 1; }

# --- Pre-flight Checks --------------------------------------------------------
preflight_checks() {
    log "Running pre-flight checks..."
    if [ "$(whoami)" != "${USER}" ]; then
        error "Script must be run as user '${USER}'. Current user is '$(whoami)'"
    fi
    if [ ! -d "${REPO_DIR}" ]; then
        error "Kodakclout repository not found at ${REPO_DIR}. Please clone it first."
    fi
    success "Pre-flight checks passed."
}

# --- Fix File Permissions and Ownership ---------------------------------------
fix_permissions() {
    log "Fixing file permissions and ownership..."
    sudo chown -R ${USER}:${USER} ${HOME_DIR}/Kodakclout || error "Failed to change ownership of Kodakclout"
    sudo chown -R ${USER}:${USER} ${HOME_DIR}/Clutch || warn "Clutch directory not found or failed to change ownership, continuing."
    success "File permissions fixed."
}

# --- Write .env file ----------------------------------------------------------
write_env_file() {
    log "Writing server/.env file..."
    cat << EOF > ${REPO_DIR}/server/.env
PORT=8080
NODE_ENV=production
DATABASE_URL=mysql://${DB_USER}:${DB_PASS}@localhost:3306/${DB_NAME}
JWT_SECRET=${JWT_SECRET}
PASSWORD_SALT_ROUNDS=12
CLUTCH_API_URL=http://localhost:8081
CLUTCH_API_KEY=${CLUTCH_API_KEY}
CLIENT_URL=https://cloutscape.org
DOMAIN=cloutscape.org
EOF
    success "server/.env file written."
}

# --- Install Dependencies and Build Project -----------------------------------
install_and_build() {
    log "Installing pnpm dependencies and building project..."
    cd ${REPO_DIR}
    pnpm install --frozen-lockfile || error "pnpm install failed."
    pnpm build || error "Project build failed."
    success "Dependencies installed and project built."
}

# --- Patch Compiled Files -----------------------------------------------------


# --- Update Clutch SQLite Databases -------------------------------------------
update_clutch_db() {
    log "Updating Clutch SQLite databases..."
    CLUTCH_DB_PATH="${CLUTCH_DIR}/db"

    if [ ! -d "${CLUTCH_DB_PATH}" ]; then
        warn "Clutch database directory not found at ${CLUTCH_DB_PATH}. Skipping database updates."
        return 0
    fi

    # Update club table
    log "Updating club table..."
    sqlite3 ${CLUTCH_DB_PATH}/club.db "UPDATE club SET balance = 1000000 WHERE id = 1;" || warn "Failed to update club.db"

    # Update user table
    log "Updating user table..."
    sqlite3 ${CLUTCH_DB_PATH}/user.db "UPDATE user SET balance = 1000000 WHERE id = 1;" || warn "Failed to update user.db"

    # Update props table
    log "Updating props table..."
    sqlite3 ${CLUTCH_DB_PATH}/props.db "UPDATE props SET value = 1 WHERE key = 'game_count';" || warn "Failed to update props.db"

    success "Clutch SQLite databases updated."
}

# --- Seed Games Table ---------------------------------------------------------
seed_games_table() {
    log "Seeding games table with 340+ games..."
    cd ${REPO_DIR}/server
    pnpm tsx src/db/seed-games.ts || error "Failed to seed games table."
    success "Games table seeded."
}

# --- Start/Restart PM2 Processes ----------------------------------------------
manage_pm2_processes() {
    log "Managing PM2 processes..."
    # Stop existing processes
    pm2 stop kodakclout || true
    pm2 delete kodakclout || true
    pm2 stop clutch-engine || true
    pm2 delete clutch-engine || true

    # Start Clutch engine
    log "Starting Clutch engine via PM2..."
    pm2 start ${CLUTCH_ENGINE_PATH} --name clutch-engine -- web -c degens777den.yaml --port 8081 || error "Failed to start Clutch engine."

    # Start Kodakclout server
    log "Starting Kodakclout server via PM2..."
    pm2 start ${REPO_DIR}/server/dist/server/src/index.js --name kodakclout --node-args="--experimental-json-modules" || error "Failed to start Kodakclout server."

    # Save PM2 configuration for persistence
    pm2 save || error "Failed to save PM2 configuration."
    pm2 startup || error "Failed to configure PM2 startup."
    success "PM2 processes managed."
}

# --- Verify Health Endpoint ---------------------------------------------------
verify_health() {
    log "Verifying health endpoint..."
    ATTEMPTS=10
    for i in $(seq 1 $ATTEMPTS);
    do
        HEALTH_STATUS=$(curl -s http://localhost:8080/api/health || true)
        if echo "$HEALTH_STATUS" | grep -q '"status":"ok"' && echo "$HEALTH_STATUS" | grep -q '"database":{"status":"connected"}'; then
            success "Health check passed: ${HEALTH_STATUS}"
            return 0
        fi
        log "Attempt $i/$ATTEMPTS: Health check failed. Retrying in 5 seconds..."
        sleep 5
    done
    error "Health check failed after $ATTEMPTS attempts. Output: ${HEALTH_STATUS}"
}

# --- Main Execution -----------------------------------------------------------
main() {
    echo -e "\n\e[1;36m███████╗██████╗  █████╗ ██████╗  █████╗  ██████╗██╗     ██╗   ██╗██╗   ██╗████████╗\e[0m"
    echo -e "\e[1;36m██╔════╝██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔════╝██║     ██║   ██║██║   ██║╚══██╔══╝\e[0m"
    echo -e "\e[1;36m█████╗  ██████╔╝███████║██████╔╝███████║██║     ██║     ██║   ██║██║   ██║   ██║   \e[0m"
    echo -e "\e[1;36m██╔══╝  ██╔══██╗██╔══██║██╔══██╗██╔══██║██║     ██║     ██║   ██║██║   ██║   ██║   \e[0m"
    echo -e "\e[1;36m███████╗██║  ██║██║  ██║██║  ██║██║  ██║╚██████╗███████╗╚██████╔╝╚██████╔╝   ██║   \e[0m"
    echo -e "\e[1;36m╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚══════╝ ╚═════╝  ╚═════╝    ╚═╝   \e[0m"
    echo -e "\n\e[1;36m                     ONE-CLICK DEPLOYMENT SCRIPT\e[0m\n"

    preflight_checks
    fix_permissions
    write_env_file
    install_and_build

    update_clutch_db     # This will be replaced with actual DB update logic
    seed_games_table     # This will be replaced with actual seeding logic
    manage_pm2_processes
    verify_health

    success "Kodakclout deployment completed successfully!"
    echo "Frontend URL: https://cloutscape.org"
    echo "API Health: http://localhost:8080/api/health"
}

main
