#!/bin/bash
set -euo pipefail

# ─── Colors & Visuals ────────────────────────────────────────────────────────
GOLD='\033[0;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

banner() {
    clear
    echo -e "${GOLD}${BOLD}"
    echo "  ██╗  ██╗ ██████╗ ██████╗  █████╗ ██╗  ██╗ ██████╗██╗      ██████╗ ██╗   ██╗████████╗"
    echo "  ██║ ██╔╝██╔═══██╗██╔══██╗██╔══██╗██║ ██╔╝██╔════╝██║     ██╔═══██╗██║   ██║╚══██╔══╝"
    echo "  █████╔╝ ██║   ██║██║  ██║███████║█████╔╝ ██║     ██║     ██║   ██║██║   ██║   ██║   "
    echo "  ██╔═██╗ ██║   ██║██║  ██║██╔══██║██╔═██╗ ██║     ██║     ██║   ██║██║   ██║   ██║   "
    echo "  ██║  ██╗╚██████╔╝██████╔╝██║  ██║██║  ██╗╚██████╗███████╗╚██████╔╝╚██████╔╝   ██║   "
    echo "  ╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚══════╝ ╚═════╝  ╚═════╝    ╚═╝   "
    echo -e "  MASTER CRAFTER ENGINE v1.0 | AUTONOMOUS DEPLOYMENT & BRANDING${NC}\n"
}

log() { echo -e "${BLUE}[$(date +'%T')]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }

# ─── Orchestration Logic ─────────────────────────────────────────────────────

configure_branding() {
    banner
    echo -e "${CYAN}${BOLD}─── BRANDING CONFIGURATION ───${NC}"
    read -p "Enter App Name [Kodakclout]: " APP_NAME
    APP_NAME=${APP_NAME:-Kodakclout}
    
    read -p "Enter Primary Color (HEX) [#ff0055]: " PRIMARY_COLOR
    PRIMARY_COLOR=${PRIMARY_COLOR:-#ff0055}
    
    read -p "Enter Secondary Color (HEX) [#7000ff]: " SECONDARY_COLOR
    SECONDARY_COLOR=${SECONDARY_COLOR:-#7000ff}

    log "Applying branding to engine..."
    # Update shared constants
    sed -i "s/APP_NAME = \".*\"/APP_NAME = \"$APP_NAME\"/" shared/src/constants.ts || true
    
    # Update CSS variables in index.css
    # Convert HEX to HSL for Tailwind (simplified approach)
    # For now, we'll update the primary color variable directly
    sed -i "s/--primary: .*/--primary: 0 84% 60%; \/* Updated by Crafter *\//" client/src/index.css || true
    
    # Update Home.tsx background gradients
    sed -i "s/background: 'linear-gradient(45deg, .*, .*)/background: 'linear-gradient(45deg, $PRIMARY_COLOR, $SECONDARY_COLOR)/" client/src/pages/Home.tsx || true
    
    log "Branding applied: $APP_NAME ($PRIMARY_COLOR / $SECONDARY_COLOR)"
    log "Rebuilding frontend to apply changes..."
    pnpm --filter @kodakclout/client build
}

deploy_engine() {
    banner
    echo -e "${CYAN}${BOLD}─── AUTONOMOUS DEPLOYMENT ───${NC}"
    log "Initializing precision deployment..."
    
    # Check for root
    if [[ $EUID -ne 0 ]]; then
       error "Deployment requires root privileges. Please run with sudo."
       return
    fi

    # Run the main deploy script
    bash deploy.sh
}

sync_engine() {
    banner
    echo -e "${CYAN}${BOLD}─── ENGINE SYNC ───${NC}"
    log "Synchronizing Kodakclout core with local engine..."
    git pull origin main
    pnpm install
    pnpm build
    pm2 restart kodakclout
    
    # Setup Health Engine Cron
    log "Installing Autonomous Health Engine..."
    chmod +x scripts/health-engine.sh
    (crontab -l 2>/dev/null | grep -v "health-engine.sh"; echo "*/5 * * * * $(pwd)/scripts/health-engine.sh") | crontab -
    
    success "Engine synchronized, rebooted, and Health Engine active."
}

# ─── Main Menu ───────────────────────────────────────────────────────────────

while true; do
    banner
    echo -e "${BOLD}Select an operation:${NC}"
    echo -e "1) ${CYAN}Configure Branding${NC} (Name, Colors, Identity)"
    echo -e "2) ${GREEN}Full Autonomous Deploy${NC} (Precision Setup)"
    echo -e "3) ${BLUE}Sync & Update Engine${NC} (Zero-Downtime Update)"
    echo -e "4) ${GOLD}View Proliferation Roadmap${NC}"
    echo -e "q) Exit Crafter"
    echo
    read -p "Choice: " choice

    case $choice in
        1) configure_branding; read -p "Press enter to continue..." ;;
        2) deploy_engine; read -p "Press enter to continue..." ;;
        3) sync_engine; read -p "Press enter to continue..." ;;
        4) cat PROLIFERATION.md; read -p "Press enter to continue..." ;;
        q) exit 0 ;;
        *) echo "Invalid choice"; sleep 1 ;;
    esac
done
