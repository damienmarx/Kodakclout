# Kodakclout: Unified Casino Platform

Kodakclout is a modern, full-stack casino platform designed for seamless integration with the Clutch game engine. This repository contains the backend (Node.js/Express/tRPC), frontend (React/Vite), and shared utilities, providing a robust foundation for online gaming experiences.

## Features

-   **Full-Stack Architecture**: Node.js backend with Express and tRPC, React frontend with Vite.
-   **Clutch Engine Integration**: Seamlessly connects with the Clutch game engine for a wide variety of casino games.
-   **MariaDB Database**: Persistent storage for user data, game states, and transactions.
-   **PM2 Process Management**: Ensures high availability and automatic restarts for both Kodakclout and Clutch services.
-   **Cloudflare Tunnel Support**: Secure and efficient public access via Cloudflare.
-   **Idempotent Deployment**: A single script for reliable and repeatable deployments.

## Deployment

This project utilizes a comprehensive, idempotent Bash script (`deploy_complete.sh`) to automate the entire deployment process on a Debian VPS. This script handles dependencies, configuration, service management, and health checks, ensuring a consistent and reliable setup.

### Prerequisites

Before running the deployment script, ensure your Debian VPS meets the following requirements:

-   **Operating System**: Debian 12+.
-   **Node.js**: Version 20+.
-   **pnpm**: Package manager.
-   **PM2**: Process manager.
-   **MariaDB**: Database server.
-   **Go**: Programming language (for Clutch engine).
-   **Cloudflare Tunnel**: Already configured and running (the script will verify its status).
-   **GitHub CLI (`gh`)**: Configured for access to `damienmarx/Kodakclout` and `damienmarx/Clutch`.

### How to Deploy

To deploy or update the Kodakclout platform and Clutch engine, follow these steps on your VPS as the `damien` user (or a user with `sudo` privileges):

1.  **Navigate to your Kodakclout directory and pull the latest changes:**
    ```bash
    cd /home/damien/Kodakclout
    git pull origin main
    ```

2.  **Navigate to your Clutch directory and pull the latest changes:**
    ```bash
    cd /home/damien/Clutch
    git pull origin main
    ```

3.  **Execute the complete deployment script:**
    ```bash
    cd /home/damien/Kodakclout
    chmod +x deploy_complete.sh
    ./deploy_complete.sh
    ```

The `deploy_complete.sh` script is designed to be idempotent, meaning it can be run multiple times without causing unintended side effects. It will automatically detect and correct common configuration issues.

### What `deploy_complete.sh` Does

The deployment script performs the following actions:

1.  **Fixes File Permissions**: Ensures the `damien` user has appropriate read/write permissions for both Kodakclout and Clutch directories.
2.  **Cleans Up PM2 Processes**: Stops and deletes any existing `kodakclout` and `clutch-engine` PM2 processes. It also attempts to free up ports 8080 and 8081 if they are stuck.
3.  **Builds Kodakclout**: Installs `pnpm` if missing, then runs `pnpm install --no-frozen-lockfile` and `pnpm run build`. It then creates a symbolic link from `client/dist` to `server/dist/client/dist` to ensure the frontend is correctly served by the backend.
4.  **Configures and Starts Clutch Engine**: Ensures the `degens777den.yaml` configuration file specifies `port-http: ":8081"`. It builds the `clutch-server` binary if it doesn't exist and starts the Clutch engine via PM2 under the name `clutch-engine`. The script includes a loop to wait and verify that the Clutch engine is responding on port 8081 via its `/ping` endpoint.
5.  **Updates Kodakclout's `.env`**: Automatically extracts the `access-key` from `degens777den.yaml` and sets it as `CLUTCH_API_KEY` in Kodakclout's `server/.env` file. It also ensures `CLUTCH_API_URL` is set to `http://localhost:8081`.
6.  **Starts Kodakclout Backend**: Identifies the correct entry point for the Kodakclout server (`server/dist/server/src/index.js` or similar) and starts it via PM2 under the name `kodakclout`.
7.  **Executes Game Seeding Script**: Runs `pnpm exec tsx scripts/seed-games.ts`. If this script fails (e.g., due to no games found), it includes a fallback mechanism to directly fetch games from the Clutch `/game/list` API and insert them into the database using a temporary TypeScript script.
8.  **Verifies Cloudflare Tunnel**: Checks the status of the `cloudflared` service and attempts to restart it if it's not running.
9.  **Performs Final Health Checks**: Queries the Kodakclout health endpoint (`http://localhost:8080/api/health`) and verifies that the `clutch` status is reported as `"healthy"` or `"connected"`.

## Verification

After the `deploy_complete.sh` script finishes, you can verify the deployment status using the following methods:

-   **PM2 Status**: Check that both `kodakclout` and `clutch-engine` processes are online:
    ```bash
    pm2 list
    ```
-   **Kodakclout Health**: Verify the backend health and Clutch integration status:
    ```bash
    curl http://localhost:8080/api/health
    # Expected output should include: "clutch":"healthy" or "clutch":"connected"
    ```
-   **Clutch Engine Health**: Confirm the Clutch engine is responsive:
    ```bash
    curl http://localhost:8081/ping
    # Expected output: HTTP 200 OK
    ```
-   **Frontend Access**: Visit `https://cloutscape.org` in your browser. The home page should load without errors, and navigating to the Games section should display the full library of 340+ slots.

## Configuration

### Kodakclout (`server/.env`)

The `server/.env` file in the Kodakclout directory contains critical environment variables. The `deploy_complete.sh` script will automatically update `CLUTCH_API_URL` and `CLUTCH_API_KEY`. Other variables you might need to configure manually include:

-   `PORT`: The port Kodakclout listens on (default: `8080`).
-   `NODE_ENV`: Set to `production` for production environments.
-   `DATABASE_URL`: MariaDB connection string.
-   `JWT_SECRET`: Secret key for JWT authentication.
-   `CLIENT_URL`: The public URL of your frontend (e.g., `https://cloutscape.org`).

### Clutch (`degens777den.yaml`)

The `degens777den.yaml` file in the Clutch directory configures the game engine. The `deploy_complete.sh` script ensures `port-http: ":8081"` is set. Key sections include:

-   `authentication`: Defines JWT access and refresh token TTLs and keys.
-   `web-server`: Configures HTTP server settings, including `port-http` and `trusted-proxies` (important for Cloudflare integration).
-   `database`: Specifies SQLite database files (`degens777den-club.sqlite`, `degens777den-spin.sqlite`).

## Project Structure

### Kodakclout

-   `client/`: React frontend application.
-   `server/`: Node.js backend application.
-   `shared/`: Shared TypeScript types and constants.
-   `scripts/`: Utility scripts, including `deploy_complete.sh` and `seed-games.ts`.

### Clutch

-   `api/`: Go source code for API handlers and routing.
-   `cmd/`: Cobra commands for application startup.
-   `config/`: Configuration structures and loading logic.
-   `degens777den.yaml`: Deployment-specific configuration for the game engine.
-   `main.go`: Main entry point for the Go application.

## Contributing

Contributions are welcome! Please refer to the project's issue tracker for open tasks or submit pull requests with improvements.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.

---

*Generated by Manus AI*
