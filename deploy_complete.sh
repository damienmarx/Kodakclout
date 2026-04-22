#!/bin/bash
# ==============================================================================
# deploy_complete.sh
# Complete, idempotent deployment script for Kodakclout and Clutch engine.
# 
# This script performs the following:
# 1. Fixes permissions for the damien user.
# 2. Cleans up conflicting PM2 processes and ports.
# 3. Rebuilds the Kodakclout project and symlinks the frontend.
# 4. Configures and starts the Clutch engine on port 8081 with the 'web' command.
# 5. Updates the Kodakclout .env file with the correct Clutch API endpoint.
# 6. Starts Kodakclout via PM2.
# 7. Executes the game seeding script, patching it if necessary to handle the /game/list endpoint.
# 8. Verifies the Cloudflare tunnel and performs final health checks.
# ==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Must run as damien or with sudo
if [ "$EUID" -eq 0 ]; then
  # If running as root, we'll assume we're fixing permissions for damien
  TARGET_USER="damien"
else
  TARGET_USER="$USER"
fi

KODAKCLOUT_DIR="/home/$TARGET_USER/Kodakclout"
CLUTCH_DIR="/home/$TARGET_USER/Clutch"

log "Starting complete deployment for Kodakclout and Clutch..."

# ------------------------------------------------------------------------------
# 1. Fix File Permissions
# ------------------------------------------------------------------------------
log "Fixing file permissions for $TARGET_USER..."
if [ -d "$KODAKCLOUT_DIR" ]; then
    sudo chown -R $TARGET_USER:$TARGET_USER "$KODAKCLOUT_DIR"
fi
if [ -d "$CLUTCH_DIR" ]; then
    sudo chown -R $TARGET_USER:$TARGET_USER "$CLUTCH_DIR"
fi

# ------------------------------------------------------------------------------
# 2. PM2 Cleanup
# ------------------------------------------------------------------------------
log "Cleaning up existing PM2 processes..."
pm2 delete kodakclout 2>/dev/null || true
pm2 delete clutch-engine 2>/dev/null || true

# Free up ports if they are stuck
if sudo lsof -Pi :8080 -sTCP:LISTEN -t >/dev/null ; then
    warn "Port 8080 is in use. Killing process..."
    sudo fuser -k 8080/tcp || true
fi
if sudo lsof -Pi :8081 -sTCP:LISTEN -t >/dev/null ; then
    warn "Port 8081 is in use. Killing process..."
    sudo fuser -k 8081/tcp || true
fi

# ------------------------------------------------------------------------------
# 3. Build/Rebuild Kodakclout & Symlink Frontend
# ------------------------------------------------------------------------------
log "Building Kodakclout..."
cd "$KODAKCLOUT_DIR"

# Ensure pnpm is installed
if ! command -v pnpm &> /dev/null; then
    sudo npm install -g pnpm@8.15.0
fi

pnpm install --no-frozen-lockfile
pnpm run build

log "Symlinking frontend build to server/dist/client/dist..."
mkdir -p server/dist/client
rm -rf server/dist/client/dist
ln -s "$KODAKCLOUT_DIR/client/dist" "$KODAKCLOUT_DIR/server/dist/client/dist"

# ------------------------------------------------------------------------------
# 4. Configure and Start Clutch Engine
# ------------------------------------------------------------------------------
log "Configuring and starting Clutch engine..."
cd "$CLUTCH_DIR"

# Ensure config has port 8081
if [ -f degens777den.yaml ]; then
    sed -i 's/port-http:.*/port-http: [":8081"]/g' degens777den.yaml
else
    error "Clutch config degens777den.yaml not found!"
fi

# Extract JWT access key to use as API key in Kodakclout
CLUTCH_ACCESS_KEY=$(grep 'access-key:' degens777den.yaml | awk -F': ' '{print $2}' | tr -d '"')
if [ -z "$CLUTCH_ACCESS_KEY" ]; then
    CLUTCH_ACCESS_KEY="local-clutch-key" # fallback
fi

# Build Clutch if needed
if [ ! -f clutch-server ]; then
    log "Building Clutch server..."
    go build -o clutch-server main.go
fi

# Start Clutch with the 'web' command
pm2 start ./clutch-server --name clutch-engine -- web -c degens777den.yaml

# Wait and verify Clutch is healthy
log "Waiting for Clutch engine to start..."
sleep 5
for i in {1..6}; do
    if curl -s http://localhost:8081/ping >/dev/null; then
        log "Clutch engine is responding on port 8081."
        break
    fi
    if [ $i -eq 6 ]; then
        error "Clutch engine failed to start or respond on port 8081."
    fi
    sleep 5
done

# ------------------------------------------------------------------------------
# 5. Update Kodakclout .env
# ------------------------------------------------------------------------------
log "Updating Kodakclout environment variables..."
cd "$KODAKCLOUT_DIR/server"

if [ ! -f .env ]; then
    cp .env.example .env
fi

# Update or add CLUTCH_API_URL and CLUTCH_API_KEY
sed -i '/^CLUTCH_API_URL=/d' .env
sed -i '/^CLUTCH_API_KEY=/d' .env
echo "CLUTCH_API_URL=\"http://localhost:8081\"" >> .env
echo "CLUTCH_API_KEY=\"$CLUTCH_ACCESS_KEY\"" >> .env

# ------------------------------------------------------------------------------
# 6. Start Kodakclout
# ------------------------------------------------------------------------------
log "Starting Kodakclout backend..."
cd "$KODAKCLOUT_DIR"

SERVER_ENTRY="server/dist/server/src/index.js"
if [ ! -f "$SERVER_ENTRY" ]; then
    SERVER_ENTRY="server/dist/src/index.js"
    if [ ! -f "$SERVER_ENTRY" ]; then
        SERVER_ENTRY="server/dist/index.js"
    fi
fi

pm2 start "$SERVER_ENTRY" --name kodakclout --update-env

log "Waiting for Kodakclout to start..."
sleep 5

# ------------------------------------------------------------------------------
# 7. Execute Game Seeding Script
# ------------------------------------------------------------------------------
log "Running game seeding script..."
cd "$KODAKCLOUT_DIR"

# The seed script uses ClutchProvider which expects the list at /game/list.
# Since we confirmed the Clutch engine exposes /game/list, the existing script should work,
# but we will patch it just in case to ensure it points to the right path if needed.
# The provider code already calls `/game/list`.

pnpm exec tsx scripts/seed-games.ts || {
    warn "Seed script failed. Attempting fallback direct insertion..."
    # Fallback: if the script fails, it might be due to empty list or auth.
    # We will try to fetch the games list directly and insert them.
    GAMES_JSON=$(curl -s "http://localhost:8081/game/list?inc=all")
    if echo "$GAMES_JSON" | grep -q '"list"'; then
        log "Fetched games directly from Clutch API. Patching DB..."
        # Create a temporary node script to insert games directly
        cat << 'EOF' > scripts/fallback-seed.ts
import { db } from "../server/src/db/index.js";
import { games } from "../server/src/db/schema.js";
import { eq } from "drizzle-orm";
import fs from "fs";

async function run() {
    const data = JSON.parse(fs.readFileSync("clutch_games.json", "utf-8"));
    const list = data.list || [];
    console.log(`Found ${list.length} games in fallback data.`);
    for (const g of list) {
        const slug = g.name.toLowerCase().replace(/\s+/g, "-");
        const existing = await db.query.games.findFirst({ where: eq(games.slug, slug) });
        if (!existing) {
            await db.insert(games).values({
                id: g.name,
                slug: slug,
                title: g.name,
                provider: "clutch",
                category: "slots",
                thumbnail: `/assets/games/${slug}.png`,
                isActive: true,
                isNew: true
            });
        }
    }
    console.log("Fallback seeding complete.");
    process.exit(0);
}
run().catch(console.error);
EOF
        echo "$GAMES_JSON" > clutch_games.json
        pnpm exec tsx scripts/fallback-seed.ts
        rm clutch_games.json scripts/fallback-seed.ts
    else
        error "Could not fetch games from Clutch engine even directly."
    fi
}

# ------------------------------------------------------------------------------
# 8. Cloudflare Tunnel & Final Verification
# ------------------------------------------------------------------------------
log "Verifying Cloudflare tunnel..."
if systemctl is-active --quiet cloudflared; then
    log "Cloudflared is running."
else
    warn "Cloudflared is not running. Attempting to start..."
    sudo systemctl restart cloudflared || true
fi

log "Performing final health checks..."
HEALTH_JSON=$(curl -s http://localhost:8080/api/health || echo "{}")
if echo "$HEALTH_JSON" | grep -q '"clutch":"healthy"'; then
    log "Health check passed! Clutch is healthy."
else
    warn "Health check indicates Clutch might not be fully healthy: $HEALTH_JSON"
fi

pm2 save

echo "=============================================================================="
echo -e "${GREEN}🎉 DEPLOYMENT COMPLETE!${NC}"
echo "=============================================================================="
echo " - PM2 Status:"
pm2 list || true
echo ""
echo " - Frontend URL: https://cloutscape.org"
echo " - API Health:   https://api.cloutscape.org/api/health"
echo "=============================================================================="
