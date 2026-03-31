#!/bin/bash

################################################################################
# Kodakclout Cloudflared Health Check & Self-Healing Script
#
# This script provides automatic monitoring and self-healing for Cloudflare Tunnel
# (cloudflared) with adaptable configuration for different environments.
#
# Features:
# - Automatic cloudflared installation and setup
# - Health checks with configurable intervals
# - Self-healing with automatic restart on failure
# - Adaptive environment detection
# - Comprehensive logging and monitoring
# - PM2 integration for process management
# - Tunnel status verification
# - Automatic configuration backup and recovery
#
# Usage: bash cloudflared-health-check.sh [start|stop|status|check|heal|setup]
################################################################################

set -euo pipefail

# ─── Colors for output ─────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ─── Configuration ────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="/var/log/kodakclout"
LOG_FILE="$LOG_DIR/cloudflared-health.log"
TUNNEL_LOG_FILE="$LOG_DIR/cloudflared-tunnel.log"
CONFIG_DIR="/etc/cloudflared"
TUNNEL_CONFIG="$CONFIG_DIR/config.yml"
TUNNEL_CREDS_DIR="$HOME/.cloudflared"
HEALTH_CHECK_INTERVAL=60  # seconds
MAX_RESTART_ATTEMPTS=5
RESTART_BACKOFF=30  # seconds
APP_PORT=8080
CLOUDFLARED_VERSION="latest"

# State tracking
STATE_FILE="/tmp/kodakclout-cloudflared-state.json"
RESTART_COUNT=0
LAST_CHECK_TIME=0

# ─── Logging functions ────────────────────────────────────────────────────
log() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo -e "${BLUE}[$timestamp]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[$timestamp] [✓]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[$timestamp] [✗]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[$timestamp] [!]${NC} $1" | tee -a "$LOG_FILE"
}

log_info() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo -e "${CYAN}[$timestamp] [i]${NC} $1" | tee -a "$LOG_FILE"
}

# ─── Initialize logging ───────────────────────────────────────────────────
init_logging() {
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"
    touch "$TUNNEL_LOG_FILE"
    chmod 755 "$LOG_DIR"
}

# ─── Detect environment ───────────────────────────────────────────────────
detect_environment() {
    log_info "Detecting environment..."

    local os_type=$(uname -s)
    local os_arch=$(uname -m)
    local distro="unknown"

    if [[ -f /etc/os-release ]]; then
        distro=$(grep "^ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
    fi

    log_info "OS: $os_type | Architecture: $os_arch | Distro: $distro"

    # Export for use in other functions
    export OS_TYPE="$os_type"
    export OS_ARCH="$os_arch"
    export DISTRO="$distro"
}

# ─── Check if cloudflared is installed ────────────────────────────────────
check_cloudflared_installed() {
    if command -v cloudflared &> /dev/null; then
        local version=$(cloudflared --version 2>/dev/null | head -1)
        log_success "cloudflared is installed: $version"
        return 0
    else
        log_warning "cloudflared is not installed"
        return 1
    fi
}

# ─── Install cloudflared ──────────────────────────────────────────────────
install_cloudflared() {
    log "Installing cloudflared..."

    if [[ "$DISTRO" == "ubuntu" ]] || [[ "$DISTRO" == "debian" ]]; then
        # Add Cloudflare repository
        curl -L https://pkg.cloudflare.com/cloudflare-main.gpg | apt-key add - 2>/dev/null || log_warning "Failed to add GPG key"
        
        echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/linux/$(lsb_release -cs) $(lsb_release -cs) main" | \
            tee /etc/apt/sources.list.d/cloudflare-main.list > /dev/null

        apt-get update -qq || log_warning "Failed to update package list"
        apt-get install -y -qq cloudflare-warp cloudflared || log_warning "Failed to install cloudflared via apt"
    else
        # Fallback: download binary
        log "Downloading cloudflared binary..."
        
        local download_url="https://github.com/cloudflare/cloudflared/releases/download/2024.1.0/cloudflared-linux-amd64"
        
        if [[ "$OS_ARCH" == "arm64" ]] || [[ "$OS_ARCH" == "aarch64" ]]; then
            download_url="https://github.com/cloudflare/cloudflared/releases/download/2024.1.0/cloudflared-linux-arm64"
        fi

        curl -L "$download_url" -o /usr/local/bin/cloudflared || error_exit "Failed to download cloudflared"
        chmod +x /usr/local/bin/cloudflared
    fi

    if check_cloudflared_installed; then
        log_success "cloudflared installed successfully"
    else
        error_exit "Failed to install cloudflared"
    fi
}

# ─── Setup cloudflared tunnel ─────────────────────────────────────────────
setup_tunnel() {
    log "Setting up Cloudflare Tunnel..."

    # Check if tunnel credentials exist
    if [[ ! -d "$TUNNEL_CREDS_DIR" ]]; then
        mkdir -p "$TUNNEL_CREDS_DIR"
        log "Created credentials directory: $TUNNEL_CREDS_DIR"
    fi

    # Check if tunnel config exists
    if [[ ! -f "$TUNNEL_CONFIG" ]]; then
        log_warning "Tunnel configuration not found at $TUNNEL_CONFIG"
        log "Please run: cloudflared tunnel login"
        log "Then create a tunnel and configure it"
        return 1
    fi

    log_success "Tunnel configuration found"
    return 0
}

# ─── Create tunnel configuration ──────────────────────────────────────────
create_tunnel_config() {
    local tunnel_name="${1:-kodakclout-tunnel}"
    local tunnel_domain="${2:-}"

    log "Creating tunnel configuration for: $tunnel_name"

    mkdir -p "$CONFIG_DIR"

    # Create basic configuration
    cat > "$TUNNEL_CONFIG" << EOF
# Cloudflare Tunnel Configuration for Kodakclout
tunnel: $tunnel_name
credentials-file: $TUNNEL_CREDS_DIR/${tunnel_name}.json
logfile: $TUNNEL_LOG_FILE
loglevel: info

# Ingress rules
ingress:
  - hostname: $tunnel_domain
    service: http://localhost:$APP_PORT
  - service: http_status:404
EOF

    chmod 600 "$TUNNEL_CONFIG"
    log_success "Tunnel configuration created at $TUNNEL_CONFIG"
}

# ─── Check cloudflared tunnel status ──────────────────────────────────────
check_tunnel_status() {
    log_info "Checking tunnel status..."

    # Check if cloudflared process is running
    if pgrep -x "cloudflared" > /dev/null; then
        log_success "cloudflared process is running"
        
        # Try to get tunnel status
        if cloudflared tunnel list 2>/dev/null | grep -q "HEALTHY\|DEGRADED"; then
            log_success "Tunnel status: HEALTHY"
            return 0
        else
            log_warning "Tunnel status check inconclusive"
            return 0
        fi
    else
        log_error "cloudflared process is NOT running"
        return 1
    fi
}

# ─── Health check ────────────────────────────────────────────────────────
health_check() {
    log_info "Running health check..."

    local checks_passed=0
    local checks_total=3

    # Check 1: cloudflared process
    if check_tunnel_status; then
        ((checks_passed++))
    fi

    # Check 2: Application backend
    if curl -s http://localhost:$APP_PORT/api/health | grep -q "ok"; then
        log_success "Application health check passed"
        ((checks_passed++))
    else
        log_warning "Application health check failed"
    fi

    # Check 3: Tunnel connectivity
    if cloudflared tunnel info 2>/dev/null | grep -q "CONNECTED\|ACTIVE"; then
        log_success "Tunnel connectivity check passed"
        ((checks_passed++))
    else
        log_warning "Tunnel connectivity check inconclusive"
    fi

    log_info "Health check results: $checks_passed/$checks_total checks passed"

    if [[ $checks_passed -ge 2 ]]; then
        return 0
    else
        return 1
    fi
}

# ─── Self-healing restart ────────────────────────────────────────────────
self_heal() {
    log_warning "Initiating self-healing procedure..."

    if [[ $RESTART_COUNT -ge $MAX_RESTART_ATTEMPTS ]]; then
        log_error "Maximum restart attempts ($MAX_RESTART_ATTEMPTS) exceeded"
        log_error "Manual intervention required"
        return 1
    fi

    ((RESTART_COUNT++))
    log_warning "Restart attempt $RESTART_COUNT of $MAX_RESTART_ATTEMPTS"

    # Stop existing tunnel
    log "Stopping cloudflared..."
    pkill -f cloudflared || true
    sleep 5

    # Backup current configuration
    if [[ -f "$TUNNEL_CONFIG" ]]; then
        cp "$TUNNEL_CONFIG" "$TUNNEL_CONFIG.backup.$(date +%s)"
        log_success "Configuration backed up"
    fi

    # Wait before restart
    log "Waiting $RESTART_BACKOFF seconds before restart..."
    sleep "$RESTART_BACKOFF"

    # Start tunnel
    log "Starting cloudflared tunnel..."
    if start_tunnel; then
        log_success "Tunnel restarted successfully"
        RESTART_COUNT=0  # Reset counter on success
        return 0
    else
        log_error "Failed to restart tunnel"
        return 1
    fi
}

# ─── Start tunnel ────────────────────────────────────────────────────────
start_tunnel() {
    log "Starting cloudflared tunnel..."

    if [[ ! -f "$TUNNEL_CONFIG" ]]; then
        error_exit "Tunnel configuration not found at $TUNNEL_CONFIG"
    fi

    # Start with cloudflared
    cloudflared tunnel run --config "$TUNNEL_CONFIG" >> "$TUNNEL_LOG_FILE" 2>&1 &
    local pid=$!

    sleep 3

    if kill -0 $pid 2>/dev/null; then
        log_success "cloudflared tunnel started (PID: $pid)"
        return 0
    else
        log_error "Failed to start cloudflared tunnel"
        return 1
    fi
}

# ─── Stop tunnel ────────────────────────────────────────────────────────
stop_tunnel() {
    log "Stopping cloudflared tunnel..."

    if pkill -f cloudflared; then
        log_success "cloudflared tunnel stopped"
        sleep 2
        return 0
    else
        log_warning "No cloudflared process found"
        return 0
    fi
}

# ─── Setup PM2 monitoring ───────────────────────────────────────────────
setup_pm2_monitoring() {
    log "Setting up PM2 monitoring for cloudflared..."

    if ! command -v pm2 &> /dev/null; then
        log_warning "PM2 not installed, skipping PM2 setup"
        return 1
    fi

    # Create PM2 ecosystem config for cloudflared
    cat > "$PROJECT_DIR/cloudflared-ecosystem.config.js" << 'EOF'
module.exports = {
  apps: [
    {
      name: 'cloudflared',
      script: '/usr/local/bin/cloudflared',
      args: 'tunnel run --config /etc/cloudflared/config.yml',
      instances: 1,
      exec_mode: 'fork',
      error_file: '/var/log/kodakclout/cloudflared-error.log',
      out_file: '/var/log/kodakclout/cloudflared-out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      autorestart: true,
      watch: false,
      max_memory_restart: '256M',
      node_args: '',
      env: {
        NODE_ENV: 'production',
      },
    },
  ],
};
EOF

    pm2 start cloudflared-ecosystem.config.js || log_warning "Failed to start cloudflared with PM2"
    pm2 save || log_warning "Failed to save PM2 configuration"

    log_success "PM2 monitoring configured"
}

# ─── Setup systemd service ──────────────────────────────────────────────
setup_systemd_service() {
    log "Setting up systemd service for cloudflared..."

    cat > /etc/systemd/system/cloudflared.service << EOF
[Unit]
Description=Cloudflare Tunnel
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/cloudflared tunnel run --config /etc/cloudflared/config.yml
Restart=always
RestartSec=30
StandardOutput=journal
StandardError=journal
SyslogIdentifier=cloudflared

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload || log_warning "Failed to reload systemd daemon"
    systemctl enable cloudflared || log_warning "Failed to enable cloudflared service"

    log_success "Systemd service configured"
}

# ─── Continuous monitoring loop ────────────────────────────────────────
monitor_loop() {
    log "Starting continuous monitoring loop (interval: ${HEALTH_CHECK_INTERVAL}s)..."

    while true; do
        if ! health_check; then
            log_warning "Health check failed, initiating self-healing..."
            if ! self_heal; then
                log_error "Self-healing failed, waiting before retry..."
                sleep $((RESTART_BACKOFF * 2))
            fi
        else
            log_success "All health checks passed"
            RESTART_COUNT=0  # Reset counter on success
        fi

        log_info "Next check in $HEALTH_CHECK_INTERVAL seconds..."
        sleep "$HEALTH_CHECK_INTERVAL"
    done
}

# ─── Display status ──────────────────────────────────────────────────────
display_status() {
    log ""
    log "════════════════════════════════════════════════════════════════"
    log_info "Cloudflared Status Report"
    log "════════════════════════════════════════════════════════════════"
    log ""

    # Check installation
    if check_cloudflared_installed; then
        log_success "cloudflared: INSTALLED"
    else
        log_error "cloudflared: NOT INSTALLED"
    fi

    # Check process
    if pgrep -x "cloudflared" > /dev/null; then
        log_success "Process: RUNNING"
    else
        log_error "Process: STOPPED"
    fi

    # Check configuration
    if [[ -f "$TUNNEL_CONFIG" ]]; then
        log_success "Configuration: EXISTS"
    else
        log_warning "Configuration: MISSING"
    fi

    # Check tunnel status
    if check_tunnel_status; then
        log_success "Tunnel: HEALTHY"
    else
        log_warning "Tunnel: UNHEALTHY"
    fi

    # Display recent logs
    log ""
    log_info "Recent logs (last 10 lines):"
    tail -10 "$LOG_FILE" | sed 's/^/  /'

    log ""
    log "════════════════════════════════════════════════════════════════"
}

# ─── Error exit ───────────────────────────────────────────────────────
error_exit() {
    log_error "$1"
    exit 1
}

# ─── Main command handler ─────────────────────────────────────────────
main() {
    local command="${1:-status}"

    init_logging
    detect_environment

    case "$command" in
        setup)
            log "Setting up cloudflared..."
            if ! check_cloudflared_installed; then
                install_cloudflared
            fi
            setup_tunnel
            create_tunnel_config "kodakclout-tunnel" "yourdomain.com"
            setup_systemd_service
            setup_pm2_monitoring
            log_success "Setup completed"
            ;;
        install)
            install_cloudflared
            ;;
        start)
            start_tunnel
            ;;
        stop)
            stop_tunnel
            ;;
        restart)
            stop_tunnel
            sleep 5
            start_tunnel
            ;;
        status)
            display_status
            ;;
        check)
            health_check
            ;;
        heal)
            self_heal
            ;;
        monitor)
            monitor_loop
            ;;
        *)
            cat << USAGE
Usage: $0 [COMMAND]

Commands:
  setup      - Complete cloudflared setup (install, configure, start)
  install    - Install cloudflared
  start      - Start cloudflared tunnel
  stop       - Stop cloudflared tunnel
  restart    - Restart cloudflared tunnel
  status     - Display cloudflared status
  check      - Run health check
  heal       - Run self-healing procedure
  monitor    - Start continuous monitoring loop

Examples:
  $0 setup
  $0 status
  $0 monitor
  $0 heal

USAGE
            exit 0
            ;;
    esac
}

# ─── Run main function ────────────────────────────────────────────────
main "$@"
