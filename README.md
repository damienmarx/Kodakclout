# Kodakclout Monorepo - DegensDen Edition

Welcome to the **DegensDen** edition of the Kodakclout monorepo, a premium gambling private community designed for 350 elite players. This platform integrates a robust backend with a polished frontend, featuring games from the Clutch provider, all within a scalable and high-performance monorepo structure. The landing page has been styled with a dark red obsidian theme, exclusive fonts, and a unique texture to reflect the community's exclusive nature.

## 🏗️ Architecture Overview: One Frontend, Two Backends

The platform is built on a robust "One Frontend, Two Backends" architecture, allowing for optimal performance and scalability:

| Component | Technology Stack | Role & Responsibilities |
| :-------- | :--------------- | :---------------------- |
| **Frontend** | `React`, `Vite`, `TypeScript`, `TailwindCSS`, `shadcn/ui` | The user-facing interface, providing the casino lobby, game browsing, user authentication flows, and embedding the game engine via iframes. |
| **Backend (Node.js)** | `Express`, `tRPC`, `MariaDB`, `TypeScript`, `Drizzle ORM` | The primary orchestrator. It manages user accounts, sessions, game metadata, authentication, and acts as the bridge between the frontend and the high-performance Go game engine. |
| **Backend (Go)** | `Clutch Game Engine`, `GoLang`, `SQLite` | The high-performance game engine responsible for all core game logic, including RNG (Random Number Generation), game state management, and real-time game session handling. It uses SQLite for its internal, high-speed data storage. |

### 🔄 How They Work Together

1.  **User Interaction**: Players access the **React Frontend** to browse available games and manage their accounts.
2.  **Game Listing**: The **React Frontend** communicates with the **Node.js Backend** via `tRPC` to fetch the list of available games.
3.  **Engine Integration**: The **Node.js Backend** queries the **Go Backend (Clutch)** to retrieve game details and session information.
4.  **Game Launch**: When a player selects a game, the **Node.js Backend** initiates a secure game session with the **Go Backend**, which then provides a unique launch URL.
5.  **Seamless Play**: The **React Frontend** embeds this launch URL within a secure iframe, allowing players to interact directly with the high-performance **Go Game Engine** without leaving the main platform interface.

## 🟢 Current Features (Fully Functional)

As of the latest commit, the Kodakclout platform boasts the following fully operational features:

*   **Unified Build System**: A robust monorepo setup ensures that running `pnpm build` from the root correctly compiles the `shared` package, the `Node.js Server`, and the `React Frontend` in the correct order, resolving all inter-package dependencies. This includes fixes for shared folder imports and cross-package resolution.
*   **Bulletproof Deployment**: The `scripts/deploy.sh` script is hardened for **Debian** environments. It automatically detects and installs necessary system dependencies (Node.js, Go 1.25+, MariaDB client), builds both backends from source, and manages both the Node.js and Go applications using `PM2` for continuous uptime and automatic restarts. It includes auto-provisioning for Go 1.25+.
*   **Real Game Integration**: The `Node.js Backend` is fully integrated with the `Clutch Go Engine` (running on port `8081`). It can fetch real-time game lists and generate secure session launch URLs for games.
*   **Dynamic Game Lobby**: The `React Frontend` dynamically displays games synced from the `Clutch` engine. Users can browse, select, and launch games, which are then rendered within a secure iframe for a seamless playing experience.
*   **Hybrid Database Layer**: `MariaDB` is used by the Node.js backend for managing user accounts, sessions, and game metadata via Drizzle ORM. The `Clutch` engine utilizes `SQLite` for its internal, high-speed game state and logic, providing optimal performance for game operations.
*   **Secure Authentication Keys**: High-entropy, 256-bit production authentication keys have been generated and configured within the `Clutch` engine (`degens777den.yaml`) to ensure cryptographic security for all game sessions.

## 🚀 Deployment Guide (for Debian)

To deploy the entire Kodakclout platform on your Debian server, follow these steps:

1.  **Pull Latest Changes**: Ensure your local repository is up-to-date with the latest fixes and features:
    ```bash
    git pull origin main
    ```

2.  **Configure Environment Variables**: Create `.env` files in both the `server/` and `client/` directories based on their respective `.env.example` templates. The most critical variable to set in `server/.env` is your `DATABASE_URL` for MariaDB (e.g., `mysql://clout_user:clout_pass@localhost:3306/kodakclout`). You will also need to set `CLUTCH_API_URL=http://localhost:8081` and `CLUTCH_API_KEY` (from `degens777den.yaml`). Optionally, set `CLOUDFLARE_API_TOKEN` for automated tunnel setup.

3.  **Run the Unified Deployment Script**: This single command will handle all system dependency installations, Go version management, building of all components, and starting both backends with PM2:
    ```bash
    chmod +x scripts/deploy.sh
    sudo ./scripts/deploy.sh
    ```
    *The `sudo` command is necessary for installing system-level dependencies and managing services.* The script will automatically detect your Debian environment, install Go 1.25+ if needed, and ensure MariaDB is running.

4.  **Sync Game Data**: After the deployment script completes and the Clutch engine is running (typically on port `8081`), you need to populate your Kodakclout database with the available games from Clutch:
    ```bash
    cd server
    pnpm exec tsx ../scripts/seed-games.ts
    ```
    This script will fetch the game list from the running Clutch engine and insert/update them in your MariaDB database, making them visible in the frontend lobby.

## 🚦 Monitoring and Maintenance

*   **Check Application Status**: To see if both `kodakclout` (Node.js backend) and `clutch-engine` (Go backend) are running:
    ```bash
    pm2 status
    ```
*   **View Live Logs**: To see real-time logs from all managed processes:
    ```bash
    pm2 logs
    ```
*   **Restart Applications**: To restart both backends:
    ```bash
    pm2 restart all
    ```
*   **Update Code & Redeploy**: To pull new code and redeploy the entire stack:
    ```bash
    git pull origin main
    sudo ./scripts/deploy.sh
    ```

## Port Alignment and Connectivity

To ensure seamless operation, the following port configurations are used:

| Component | Development Port | Production Port (via Cloudflare) |
| :---------------------- | :--------------- | :------------------------------- |
| **Kodakclout Frontend** | `5173` | `443` (cloutscape.org) |
| **Kodakclout Backend** | `8080` | `443` (cloutscape.org/api) |
| **Clutch Backend** | `8081` | `443` (games.cloutscape.org) |

-   In **development**, the Kodakclout frontend (Vite) runs on `5173` and proxies `/api` requests to the Kodakclout backend (Express) running on `8080`. The Clutch backend runs separately on `8081`.
-   In **production**, both Kodakclout frontend and backend are served from `cloutscape.org` (port `443`) via Cloudflare Tunnel. The Clutch backend will be exposed via a subdomain, e.g., `games.cloutscape.org`, also proxied through Cloudflare Tunnel.

## Path Aliases

Path aliases are configured for improved import readability and maintainability:

-   `@/`: Maps to `client/src`
-   `@server/`: Maps to `server/src`
-   `@shared/`: Maps to `shared/src`

## Branding

All branding within the project is for **DegensDen**, a private community for 350 elite players. All references to AI, Manus, Assistants, or generated code have been removed to maintain a consistent brand identity.

## Final Deliverables

This monorepo provides:

-   A fully working, production-grade monorepo structure.
-   Clean, modern, and modular code.
-   All imports and routes correctly resolved and functional.
-   Full integration with the Clutch game provider.
-   A fully functional and polished frontend with a casino lobby UI and a dark red obsidian themed landing page.
-   A robust backend supporting authentication, game data, and launch mechanisms.
-   A fully automated, zero-input deployment script for end-to-end setup and deployment.
-   Clear instructions for both development and production environments, including port mapping and Cloudflare setup.

---

*This project was developed by Damien for DegensDen.*
