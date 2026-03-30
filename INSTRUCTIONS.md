# 📖 Kodakclout – Concise Instructions Guide

## 🛠️ Deployment (Debian)

1.  **Clone & Setup:**
    ```bash
    git clone https://github.com/damienmarx/Kodakclout.git
    cd Kodakclout
    chmod +x scripts/setup.sh
    ./scripts/setup.sh
    ```

2.  **Configure Environment:**
    Edit `server/.env` with your real credentials:
    - `DATABASE_URL`: Your MariaDB connection string.
    - `CLOUDFLARE_API_TOKEN`: Your Cloudflare API Token for automated tunnel setup.
    - `JWT_SECRET`: A high-entropy secret for authentication.
    - `CLUTCH_API_KEY`: Must match the key in `Clutch/degens777den.yaml`.

3.  **Sync Games:**
    Once the Clutch engine is running (port 8081), sync the games to your database:
    ```bash
    cd server
    pnpm exec tsx ../scripts/seed-games.ts
    ```

## 🚦 Maintenance & Monitoring

-   **Check Processes:** `pm2 status`
-   **View All Logs:** `pm2 logs`
-   **Restart All:** `pm2 restart all`
-   **Update Platform:**
    ```bash
    git pull origin main
    ./scripts/setup.sh
    ```

## 📂 Key Ports
-   **Kodakclout Backend:** `8080`
-   **Kodakclout Frontend:** `5173` (Dev)
-   **Clutch Games Engine:** `8081`

## 🔐 Security
-   Ensure `server/.env` is **never** committed to version control.
-   Always use HTTPS via the automated Cloudflared tunnel for production access.
-   Rotate `JWT_SECRET` and `CLUTCH_API_KEY` periodically.

---
*Developed by Damien Marx.*
