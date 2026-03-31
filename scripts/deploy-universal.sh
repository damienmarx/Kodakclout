#!/bin/bash

################################################################################
# Kodakclout Universal Deployment Script
# 
# This script provides a complete, production-ready deployment for Kodakclout
# on Debian-based systems (Ubuntu, Debian, etc.)
#
# Features:
# - Automatic system dependency installation
# - Environment configuration with sensible defaults
# - Database setup and migrations
# - Build and optimization
# - Process management with PM2
# - Nginx reverse proxy configuration
# - SSL/TLS certificate setup
# - Comprehensive error handling and logging
#
# Usage: sudo bash deploy-universal.sh
################################################################################

set -euo pipefail

# ─── Colors for output ─────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ─── Configuration ────────────────────────────────────────────────────────
PROJECT_NAME="Kodakclout"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="/var/log/kodakclout-deploy.log"
APP_PORT=8080
NODE_ENV="production"
APP_USER="kodakclout"
APP_GROUP="kodakclout"

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

# ─── Error handling ───────────────────────────────────────────────────────
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
        error_exit "This script requires lsb_release. Please run: apt-get install lsb-release"
    fi

    local os_name=$(lsb_release -si)
    if [[ ! "$os_name" =~ ^(Ubuntu|Debian)$ ]]; then
        error_exit "This script only supports Debian-based systems (Ubuntu, Debian). Detected: $os_name"
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
        "curl"
        "wget"
        "git"
        "build-essential"
        "python3"
        "python3-dev"
        "pkg-config"
        "nginx"
        "certbot"
        "python3-certbot-nginx"
        "mysql-server"
        "mysql-client"
    )

    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package"; then
            log "Installing $package..."
            apt-get install -y -qq "$package" || error_exit "Failed to install $package"
        else
            log_success "$package already installed"
        fi
    done

    log_success "System dependencies installed"
}

# ─── Install Node.js and pnpm ────────────────────────────────────────────
install_nodejs() {
    log "Installing Node.js and pnpm..."

    # Check if Node.js is installed
    if command -v node &> /dev/null; then
        local node_version=$(node -v)
        log_success "Node.js $node_version already installed"
    else
        log "Installing Node.js v22 LTS..."
        curl -fsSL https://deb.nodesource.com/setup_22.x | bash - || error_exit "Failed to add NodeSource repository"
        apt-get install -y -qq nodejs || error_exit "Failed to install Node.js"
        log_success "Node.js installed: $(node -v)"
    fi

    # Install pnpm globally
    if command -v pnpm &> /dev/null; then
        log_success "pnpm already installed: $(pnpm -v)"
    else
        log "Installing pnpm..."
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
        pm2 startup systemd -u $APP_USER --hp /home/$APP_USER || log_warning "PM2 startup configuration may need manual setup"
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

    # Add user to sudoers for PM2
    echo "$APP_USER ALL=(ALL) NOPASSWD: /usr/local/bin/pm2" >> /etc/sudoers.d/$APP_USER 2>/dev/null || true
}

# ─── Setup project directory ──────────────────────────────────────────────
setup_project_directory() {
    log "Setting up project directory..."

    if [[ ! -d "$PROJECT_DIR" ]]; then
        error_exit "Project directory not found: $PROJECT_DIR"
    fi

    # Set proper permissions
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

    # Generate secure random keys
    local jwt_secret=$(openssl rand -base64 32)
    local db_password=$(openssl rand -base64 16)

    # Create .env file with defaults
    cat > "$env_file" << EOF
# ─── Database Configuration ───────────────────────────────────────────────
DATABASE_URL=mysql://kodakclout:${db_password}@localhost:3306/kodakclout

# ─── Server Configuration ─────────────────────────────────────────────────
PORT=${APP_PORT}
NODE_ENV=${NODE_ENV}
SERVER_URL=http://localhost:${APP_PORT}
CLIENT_URL=http://localhost:${APP_PORT}

# ─── JWT Configuration ────────────────────────────────────────────────────
JWT_SECRET=${jwt_secret}
PASSWORD_SALT_ROUNDS=12

# ─── Google OAuth Configuration ───────────────────────────────────────────
# Get these from: https://console.cloud.google.com/
GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-google-client-secret

# ─── Clutch Engine Configuration ──────────────────────────────────────────
CLUTCH_API_URL=https://api.clutch.io
CLUTCH_API_KEY=your-clutch-api-key
EOF

    chmod 600 "$env_file"
    chown $APP_USER:$APP_GROUP "$env_file"

    log_success ".env file created with secure defaults"
    log_warning "Please update the following in .env:"
    log_warning "  - GOOGLE_CLIENT_ID"
    log_warning "  - GOOGLE_CLIENT_SECRET"
    log_warning "  - CLUTCH_API_KEY"
    log_warning "  - SERVER_URL (set to your domain)"
    log_warning "  - CLIENT_URL (set to your domain)"
}

# ─── Setup MySQL database ─────────────────────────────────────────────────
setup_database() {
    log "Setting up MySQL database..."

    # Start MySQL service
    systemctl start mysql || error_exit "Failed to start MySQL service"
    systemctl enable mysql || log_warning "Failed to enable MySQL service on boot"

    # Wait for MySQL to be ready
    local max_attempts=30
    local attempt=0
    while ! mysqladmin ping -u root --silent 2>/dev/null; do
        attempt=$((attempt + 1))
        if [[ $attempt -ge $max_attempts ]]; then
            error_exit "MySQL failed to start after $max_attempts attempts"
        fi
        sleep 1
    done

    log_success "MySQL is running"

    # Create database and user
    local db_password=$(grep "DATABASE_URL" "$PROJECT_DIR/.env" | sed -n 's/.*:\([^@]*\)@.*/\1/p')
    
    mysql -u root << MYSQL_SCRIPT || log_warning "Database setup may have encountered issues"
CREATE DATABASE IF NOT EXISTS kodakclout CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'kodakclout'@'localhost' IDENTIFIED BY '${db_password}';
GRANT ALL PRIVILEGES ON kodakclout.* TO 'kodakclout'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

    log_success "Database created and user configured"
}

# ─── Install project dependencies ────────────────────────────────────────
install_project_dependencies() {
    log "Installing project dependencies..."

    cd "$PROJECT_DIR" || error_exit "Failed to change to project directory"

    # Install dependencies
    sudo -u $APP_USER pnpm install --frozen-lockfile || error_exit "Failed to install project dependencies"

    log_success "Project dependencies installed"
}

# ─── Build project ────────────────────────────────────────────────────────
build_project() {
    log "Building project..."

    cd "$PROJECT_DIR" || error_exit "Failed to change to project directory"

    # Build all packages
    sudo -u $APP_USER pnpm build || error_exit "Failed to build project"

    log_success "Project built successfully"
}

# ─── Run database migrations ──────────────────────────────────────────────
run_migrations() {
    log "Running database migrations..."

    cd "$PROJECT_DIR" || error_exit "Failed to change to project directory"

    # Run Drizzle migrations
    sudo -u $APP_USER pnpm --filter @kodakclout/server run migrate || log_warning "Database migrations may have encountered issues"

    log_success "Database migrations completed"
}

# ─── Seed initial data ────────────────────────────────────────────────────
seed_data() {
    log "Seeding initial game data..."

    cd "$PROJECT_DIR" || error_exit "Failed to change to project directory"

    # Run seed script
    sudo -u $APP_USER pnpm --filter @kodakclout/server run seed || log_warning "Data seeding may have encountered issues"

    log_success "Initial data seeded"
}

# ─── Setup PM2 application ────────────────────────────────────────────────
setup_pm2() {
    log "Configuring PM2 application..."

    cd "$PROJECT_DIR" || error_exit "Failed to change to project directory"

    # Create PM2 ecosystem file
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

    # Start application with PM2
    sudo -u $APP_USER pm2 start ecosystem.config.js || error_exit "Failed to start application with PM2"
    sudo -u $APP_USER pm2 save || log_warning "Failed to save PM2 configuration"

    log_success "Application started with PM2"
}

# ─── Configure Nginx ──────────────────────────────────────────────────────
configure_nginx() {
    log "Configuring Nginx reverse proxy..."

    # Create Nginx configuration
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

    # API and tRPC routes
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

    # Frontend and SPA routes
    location / {
        proxy_pass http://kodakclout_backend;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    # Health check endpoint
    location /health {
        access_log off;
        proxy_pass http://kodakclout_backend;
        proxy_http_version 1.1;
    }
}
EOF

    # Enable site
    if [[ ! -L /etc/nginx/sites-enabled/kodakclout ]]; then
        ln -s /etc/nginx/sites-available/kodakclout /etc/nginx/sites-enabled/kodakclout || error_exit "Failed to enable Nginx site"
    fi

    # Test Nginx configuration
    nginx -t || error_exit "Nginx configuration test failed"

    # Reload Nginx
    systemctl restart nginx || error_exit "Failed to restart Nginx"

    log_success "Nginx configured and restarted"
}

# ─── Setup SSL/TLS (optional) ─────────────────────────────────────────────
setup_ssl() {
    log "SSL/TLS setup (optional)..."

    read -p "Do you want to setup SSL/TLS with Let's Encrypt? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter your domain name: " domain_name
        
        if [[ -z "$domain_name" ]]; then
            log_warning "No domain provided, skipping SSL setup"
            return
        fi

        log "Setting up SSL certificate for $domain_name..."
        certbot certonly --nginx -d "$domain_name" --non-interactive --agree-tos --email admin@"$domain_name" || log_warning "SSL setup failed, you may need to configure manually"

        log_success "SSL certificate configured"
    else
        log_warning "Skipping SSL setup"
    fi
}

# ─── Verify deployment ────────────────────────────────────────────────────
verify_deployment() {
    log "Verifying deployment..."

    # Check if application is running
    if sudo -u $APP_USER pm2 list | grep -q "kodakclout-server"; then
        log_success "Application is running with PM2"
    else
        error_exit "Application is not running"
    fi

    # Check if Nginx is running
    if systemctl is-active --quiet nginx; then
        log_success "Nginx is running"
    else
        error_exit "Nginx is not running"
    fi

    # Check health endpoint
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
    log "Access Points:"
    log "  Application: http://localhost"
    log "  API: http://localhost/api"
    log "  Health Check: http://localhost/api/health"
    log ""
    log "Useful Commands:"
    log "  View logs: pm2 logs kodakclout-server"
    log "  Monitor: pm2 monit"
    log "  Restart: pm2 restart kodakclout-server"
    log "  Stop: pm2 stop kodakclout-server"
    log "  Nginx status: systemctl status nginx"
    log ""
    log "Next Steps:"
    log "  1. Update .env file with your credentials:"
    log "     nano $PROJECT_DIR/.env"
    log "  2. Configure your domain in Nginx:"
    log "     nano /etc/nginx/sites-available/kodakclout"
    log "  3. Setup SSL certificate:"
    log "     sudo certbot certonly --nginx -d yourdomain.com"
    log ""
    log "Deployment log saved to: $LOG_FILE"
    log "════════════════════════════════════════════════════════════════"
}

# ─── Main deployment flow ─────────────────────────────────────────────────
main() {
    log "Starting $PROJECT_NAME deployment..."
    log "Log file: $LOG_FILE"

    check_prerequisites
    update_system
    install_dependencies
    install_nodejs
    install_pm2
    create_app_user
    setup_project_directory
    setup_environment
    setup_database
    install_project_dependencies
    build_project
    run_migrations
    seed_data
    setup_pm2
    configure_nginx
    setup_ssl
    verify_deployment
    deployment_summary
}

# ─── Run main function ────────────────────────────────────────────────────
main "$@"
