# 🎰 Kodakclout – Unified Casino Platform

Kodakclout is a modern, full-stack casino platform developed by **Damien Marx**. It integrates a high-performance Express/tRPC backend with a React/Vite frontend, powered by the **Clutch Engine** for a seamless 340+ game experience.

## 🚀 Quick Start (Debian)

The platform is optimized for Debian environments. Use the unified setup script to automate everything from dependency installation to Cloudflared tunnel startup.

```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
```

### What the Setup Script Does:
1.  **Purges Environment Conflicts:** Removes old `node_modules`, lockfiles, and build artifacts to ensure a clean slate.
2.  **System Pre-checks:** Installs missing dependencies (`mariadb`, `golang`, `pnpm`, `jq`, etc.) automatically.
3.  **Database Self-Healing:** Automatically configures MariaDB, creates the database, and sets up the `clout_user` with correct permissions.
4.  **Seamless Clutch Integration:** Automatically clones the Clutch engine repository, builds it from source, and deploys it via PM2.
5.  **Cloudflared Automation:** Automatically starts your Cloudflare Tunnel using the `CLOUDFLARE_API_TOKEN` in your `.env`.
6.  **Health Checks:** Validates that the backend and games engine are running correctly before finishing.

## 🛠️ Architecture: One Frontend, Two Backends

Kodakclout uses a "One Frontend, Two Backends" architecture for maximum performance:

| Component | Technology Stack | Role |
| :--- | :--- | :--- |
| **Frontend** | React, Vite, TailwindCSS | The user-facing interface and game lobby. |
| **Backend (Node.js)** | Express, tRPC, Drizzle ORM | Manages users, sessions, and orchestrates game launches. |
| **Backend (Go)** | Clutch Engine, GoLang | High-performance engine for RNG and core game logic. |

## 📂 Project Structure

-   `/client`: The React frontend application.
-   `/server`: The Express/tRPC backend with Drizzle ORM.
-   `/shared`: Shared code (types, schemas, constants) for end-to-end type safety.
-   `/scripts`: Automation scripts for setup, deployment, and Cloudflare.

## 🔐 Environment Variables

Ensure your `server/.env` contains the following:

```env
PORT=8080
DATABASE_URL=mysql://clout_user:clout_pass@127.0.0.1:3306/kodakclout
JWT_SECRET=your_secret_key
CLOUDFLARE_API_TOKEN=your_cloudflare_token
CLUTCH_API_URL=http://localhost:8081
CLUTCH_API_KEY=your_clutch_api_key
```

## 🚦 Monitoring

-   **Check Status:** `pm2 status`
-   **View Logs:** `pm2 logs`
-   **Restart All:** `pm2 restart all`

---
*Developed by Damien Marx for the Kodakclout community.*
