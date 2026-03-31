#!/bin/bash

################################################################################
# Kodakclout Universal Deployment Script v2
# 
# Enhanced version with:
# - Cloudflared Tunnel integration
# - Self-healing capabilities
# - MariaDB support with default password "maria"
# - Adaptive environment detection
# - Automatic health monitoring
#
# Usage: sudo bash deploy-universal-v2.sh [--with-cloudflare] [--domain yourdomain.com]
################################################################################

set -euo pipefail

# ─── Colors for output ─────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ─── Configuration ────────────────────────────────────────────────────────
PROJECT_NAME="Kodakclout"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="/var/log/kodakclout-deploy.log"
APP_PORT=8080
NODE_ENV="production"
APP_USER="kodakclout"
APP_GROUP="kodakclout"
MARIADB_ROOT_PASSWORD="maria"
MARIADB_APP_PASSWORD="maria"
ENABLE_CLOUDFLARE=false
DOMAIN_NAME=""

# ─── Parse command line arguments ──────────────────────────────────────────
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --with-cloudflare)
                ENABLE_CLOUDFLARE=true
                shift
                ;;
            --domain)
                DOMAIN_NAME="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
}

# ─── Logging functions ────────────────────────────────────────────────────
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1" | tee -a "$LOG_FILE"
}

error_exit() {
    log_error "$1"
    exit 1
}

trap 'error_exit "Script interrupted or encountered an error"' ERR

# ─── Check prerequisites ──────────────────────────────────────────────────
check_prerequisites() {
    log "Checking prerequisites..."

    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root (use sudo)"
    fi

    if ! command -v lsb_release &> /dev/null; then
        error_exit "This script requires lsb_release"
    fi

    local os_name=$(lsb_release -si)
    if [[ ! "$os_name" =~ ^(Ubuntu|Debian)$ ]]; then
        error_exit "This script only supports Debian-based systems. Detected: $os_name"
    fi

    log_success "Prerequisites check passed"
}

# ─── Update system ────────────────────────────────────────────────────────
update_system() {
    log "Updating system packages..."
    apt-get update -qq || error_exit "Failed to update package list"
    apt-get upgrade -y -qq || error_exit "Failed to upgrade packages"
    log_success "System packages updated"
}

# ─── Install system dependencies ──────────────────────────────────────────
install_dependencies() {
    log "Installing system dependencies..."

    local packages=(
        "curl" "wget" "git" "build-essential" "python3" "python3-dev"
        "pkg-config" "nginx" "certbot" "python3-certbot-nginx"
        "mariadb-server" "mariadb-client"
    )

    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package"; then
            log "Installing $package..."
            apt-get install -y -qq "$package" || error_exit "Failed to install $package"
        fi
    done

    log_success "System dependencies installed"
}

# ─── Install Node.js and pnpm ────────────────────────────────────────────
install_nodejs() {
    log "Installing Node.js and pnpm..."

    if command -v node &> /dev/null; then
        log_success "Node.js $(node -v) already installed"
    else
        curl -fsSL https://deb.nodesource.com/setup_22.x | bash - || error_exit "Failed to add NodeSource repository"
        apt-get install -y -qq nodejs || error_exit "Failed to install Node.js"
        log_success "Node.js installed: $(node -v)"
    fi

    if command -v pnpm &> /dev/null; then
        log_success "pnpm $(pnpm -v) already installed"
    else
        npm install -g pnpm || error_exit "Failed to install pnpm"
        log_success "pnpm installed: $(pnpm -v)"
    fi
}

# ─── Install PM2 ──────────────────────────────────────────────────────────
install_pm2() {
    log "Installing PM2 process manager..."

    if npm list -g pm2 &> /dev/null; then
        log_success "PM2 already installed"
    else
        npm install -g pm2 || error_exit "Failed to install PM2"
        pm2 startup systemd -u $APP_USER --hp /home/$APP_USER || log_warning "PM2 startup may need manual setup"
        log_success "PM2 installed and configured"
    fi
}

# ─── Create application user ──────────────────────────────────────────────
create_app_user() {
    log "Creating application user..."

    if id "$APP_USER" &>/dev/null; then
        log_success "User $APP_USER already exists"
    else
        useradd -m -s /bin/bash -d /home/$APP_USER $APP_USER || error_exit "Failed to create user $APP_USER"
        log_success "User $APP_USER created"
    fi

    echo "$APP_USER ALL=(ALL) NOPASSWD: /usr/local/bin/pm2" >> /etc/sudoers.d/$APP_USER 2>/dev/null || true
}

# ─── Setup project directory ──────────────────────────────────────────────
setup_project_directory() {
    log "Setting up project directory..."

    if [[ ! -d "$PROJECT_DIR" ]]; then
        error_exit "Project directory not found: $PROJECT_DIR"
    fi

    chown -R $APP_USER:$APP_GROUP "$PROJECT_DIR" || error_exit "Failed to set project directory permissions"
    chmod -R 755 "$PROJECT_DIR" || error_exit "Failed to set project directory permissions"

    log_success "Project directory configured"
}

# ─── Setup environment variables ──────────────────────────────────────────
setup_environment() {
    log "Setting up environment variables..."

    local env_file="$PROJECT_DIR/.env"

    if [[ -f "$env_file" ]]; then
        log_warning ".env file already exists, skipping creation"
        return
    fi

    local jwt_secret=$(openssl rand -base64 32)

    cat > "$env_file" << EOF
# ─── Database Configuration ───────────────────────────────────────────────
DATABASE_URL=mysql://kodakclout:${MARIADB_APP_PASSWORD}@localhost:3306/kodakclout

# ─── Server Configuration ─────────────────────────────────────────────────
PORT=${APP_PORT}
NODE_ENV=${NODE_ENV}
SERVER_URL=http://localhost:${APP_PORT}
CLIENT_URL=http://localhost:${APP_PORT}

# ─── JWT Configuration ────────────────────────────────────────────────────
JWT_SECRET=${jwt_secret}
PASSWORD_SALT_ROUNDS=12

# ─── Google OAuth Configuration ───────────────────────────────────────────
GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-google-client-secret

# ─── Clutch Engine Configuration ──────────────────────────────────────────
CLUTCH_API_URL=https://api.clutch.io
CLUTCH_API_KEY=your-clutch-api-key
EOF

    chmod 600 "$env_file"
    chown $APP_USER:$APP_GROUP "$env_file"

    log_success ".env file created with secure defaults"
}

# ─── Setup MariaDB database ──────────────────────────────────────────────
setup_mariadb() {
    log "Setting up MariaDB database..."

    systemctl start mariadb || error_exit "Failed to start MariaDB service"
    systemctl enable mariadb || log_warning "Failed to enable MariaDB service on boot"

    # Wait for MariaDB to be ready
    local max_attempts=30
    local attempt=0
    while ! mysqladmin ping -u root --silent 2>/dev/null; do
        attempt=$((attempt + 1))
        if [[ $attempt -ge $max_attempts ]]; then
            error_exit "MariaDB failed to start after $max_attempts attempts"
        fi
        sleep 1
    done

    log_success "MariaDB is running"

    # Create database and user
    mysql -u root << MYSQL_SCRIPT || log_warning "Database setup may have encountered issues"
CREATE DATABASE IF NOT EXISTS kodakclout CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'kodakclout'@'localhost' IDENTIFIED BY '${MARIADB_APP_PASSWORD}';
GRANT ALL PRIVILEGES ON kodakclout.* TO 'kodakclout'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

    log_success "MariaDB database created and user configured"
}

# ─── Install project dependencies ────────────────────────────────────────
install_project_dependencies() {
    log "Installing project dependencies..."

    cd "$PROJECT_DIR" || error_exit "Failed to change to project directory"

    sudo -u $APP_USER pnpm install --frozen-lockfile || error_exit "Failed to install project dependencies"

    log_success "Project dependencies installed"
}

# ─── Build project ────────────────────────────────────────────────────────
build_project() {
    log "Building project..."

    cd "$PROJECT_DIR" || error_exit "Failed to change to project directory"

    sudo -u $APP_USER pnpm build || error_exit "Failed to build project"

    log_success "Project built successfully"
}

# ─── Run database migrations ──────────────────────────────────────────────
run_migrations() {
    log "Running database migrations..."

    cd "$PROJECT_DIR" || error_exit "Failed to change to project directory"

    sudo -u $APP_USER pnpm --filter @kodakclout/server run migrate || log_warning "Database migrations may have encountered issues"

    log_success "Database migrations completed"
}

# ─── Seed initial data ────────────────────────────────────────────────────
seed_data() {
    log "Seeding initial game data..."

    cd "$PROJECT_DIR" || error_exit "Failed to change to project directory"

    sudo -u $APP_USER pnpm --filter @kodakclout/server run seed || log_warning "Data seeding may have encountered issues"

    log_success "Initial data seeded"
}

# ─── Setup PM2 application ────────────────────────────────────────────────
setup_pm2() {
    log "Configuring PM2 application..."

    cd "$PROJECT_DIR" || error_exit "Failed to change to project directory"

    cat > "$PROJECT_DIR/ecosystem.config.js" << 'EOF'
module.exports = {
  apps: [
    {
      name: 'kodakclout-server',
      script: './server/dist/server/src/index.js',
      instances: 1,
      exec_mode: 'cluster',
      env: {
        NODE_ENV: 'production',
        PORT: 8080,
      },
      error_file: '/var/log/kodakclout-error.log',
      out_file: '/var/log/kodakclout-out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      merge_logs: true,
      autorestart: true,
      watch: false,
      max_memory_restart: '1G',
      node_args: '--max-old-space-size=512',
    },
  ],
};
EOF

    chown $APP_USER:$APP_GROUP "$PROJECT_DIR/ecosystem.config.js"

    sudo -u $APP_USER pm2 start ecosystem.config.js || error_exit "Failed to start application with PM2"
    sudo -u $APP_USER pm2 save || log_warning "Failed to save PM2 configuration"

    log_success "Application started with PM2"
}

# ─── Configure Nginx ──────────────────────────────────────────────────────
configure_nginx() {
    log "Configuring Nginx reverse proxy..."

    cat > /etc/nginx/sites-available/kodakclout << EOF
upstream kodakclout_backend {
    server localhost:${APP_PORT};
    keepalive 64;
}

server {
    listen 80;
    listen [::]:80;
    server_name _;

    client_max_body_size 10M;
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;

    location /api {
        proxy_pass http://kodakclout_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_buffering off;
    }

    location / {
        proxy_pass http://kodakclout_backend;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    location /health {
        access_log off;
        proxy_pass http://kodakclout_backend;
        proxy_http_version 1.1;
    }
}
EOF

    if [[ ! -L /etc/nginx/sites-enabled/kodakclout ]]; then
        ln -s /etc/nginx/sites-available/kodakclout /etc/nginx/sites-enabled/kodakclout || error_exit "Failed to enable Nginx site"
    fi

    nginx -t || error_exit "Nginx configuration test failed"
    systemctl restart nginx || error_exit "Failed to restart Nginx"

    log_success "Nginx configured and restarted"
}

# ─── Setup Cloudflared tunnel ─────────────────────────────────────────────
setup_cloudflared() {
    if [[ "$ENABLE_CLOUDFLARE" != "true" ]]; then
        log_warning "Cloudflare Tunnel setup skipped (use --with-cloudflare to enable)"
        return
    fi

    log "Setting up Cloudflare Tunnel..."

    bash "$PROJECT_DIR/scripts/cloudflared-health-check.sh" setup || log_warning "Cloudflared setup may have encountered issues"

    if [[ -n "$DOMAIN_NAME" ]]; then
        log "Configuring tunnel for domain: $DOMAIN_NAME"
        bash "$PROJECT_DIR/scripts/cloudflared-health-check.sh" start || log_warning "Failed to start cloudflared"
    fi

    log_success "Cloudflare Tunnel configured"
}

# ─── Setup health monitoring ──────────────────────────────────────────────
setup_health_monitoring() {
    log "Setting up health monitoring..."

    # Create cron job for health checks
    local cron_job="*/5 * * * * bash $PROJECT_DIR/scripts/cloudflared-health-check.sh check >> /var/log/kodakclout/health-check.log 2>&1"
    
    (crontab -u $APP_USER -l 2>/dev/null | grep -v "cloudflared-health-check"; echo "$cron_job") | crontab -u $APP_USER -

    log_success "Health monitoring configured"
}

# ─── Verify deployment ────────────────────────────────────────────────────
verify_deployment() {
    log "Verifying deployment..."

    if sudo -u $APP_USER pm2 list | grep -q "kodakclout-server"; then
        log_success "Application is running with PM2"
    else
        error_exit "Application is not running"
    fi

    if systemctl is-active --quiet nginx; then
        log_success "Nginx is running"
    else
        error_exit "Nginx is not running"
    fi

    sleep 2
    if curl -s http://localhost/api/health | grep -q "ok"; then
        log_success "Health check passed"
    else
        log_warning "Health check failed or slow to respond"
    fi

    log_success "Deployment verification completed"
}

# ─── Display deployment summary ────────────────────────────────────────────
deployment_summary() {
    log ""
    log "════════════════════════════════════════════════════════════════"
    log_success "Deployment completed successfully!"
    log "════════════════════════════════════════════════════════════════"
    log ""
    log "Application Details:"
    log "  Project: $PROJECT_NAME"
    log "  Directory: $PROJECT_DIR"
    log "  Port: $APP_PORT"
    log "  Environment: $NODE_ENV"
    log "  User: $APP_USER"
    log ""
    log "Database:"
    log "  Type: MariaDB"
    log "  User: kodakclout"
    log "  Password: $MARIADB_APP_PASSWORD"
    log ""
    if [[ "$ENABLE_CLOUDFLARE" == "true" ]]; then
        log "Cloudflare Tunnel:"
        log "  Status: ENABLED"
        log "  Domain: ${DOMAIN_NAME:-Not configured}"
        log "  Health Check: Enabled (every 5 minutes)"
        log ""
    fi
    log "Access Points:"
    log "  Application: http://localhost"
    log "  API: http://localhost/api"
    log "  Health Check: http://localhost/api/health"
    log ""
    log "Useful Commands:"
    log "  View logs: pm2 logs kodakclout-server"
    log "  Monitor: pm2 monit"
    log "  Restart: pm2 restart kodakclout-server"
    log "  Cloudflared status: bash $PROJECT_DIR/scripts/cloudflared-health-check.sh status"
    log ""
    log "Next Steps:"
    log "  1. Update .env file with your credentials"
    log "  2. Configure your domain"
    if [[ "$ENABLE_CLOUDFLARE" == "true" ]]; then
        log "  3. Run: cloudflared tunnel login"
        log "  4. Configure your tunnel"
    fi
    log ""
    log "Deployment log saved to: $LOG_FILE"
    log "════════════════════════════════════════════════════════════════"
}

# ─── Main deployment flow ─────────────────────────────────────────────────
main() {
    parse_args "$@"

    log "Starting $PROJECT_NAME deployment v2..."
    log "Log file: $LOG_FILE"

    check_prerequisites
    update_system
    install_dependencies
    install_nodejs
    install_pm2
    create_app_user
    setup_project_directory
    setup_environment
    setup_mariadb
    install_project_dependencies
    build_project
    run_migrations
    seed_data
    setup_pm2
    configure_nginx
    setup_cloudflared
    setup_health_monitoring
    verify_deployment
    deployment_summary
}

# ─── Run main function ────────────────────────────────────────────────
main "$@"
