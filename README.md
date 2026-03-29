# Kodakclout Monorepo - DegensDen Edition

Welcome to the **DegensDen** edition of the Kodakclout monorepo, a premium gambling private community designed for 350 elite players. This platform integrates a robust backend with a polished frontend, featuring 340 games from the Clutch provider, all within a scalable and high-performance monorepo structure. The landing page has been styled with a dark red obsidian theme, exclusive fonts, and a unique texture to reflect the community's exclusive nature.

## Project Structure

The monorepo is organized into the following key directories:

-   **`/server`**: Contains the backend application, built with Express, tRPC, Google OAuth, and MySQL (via Drizzle ORM). It includes the integration with the Clutch game provider.
-   **`/client`**: Houses the frontend application, developed using React 18, Vite 5, and `shadcn/ui` components. It interacts with the backend via a tRPC client and displays games within iframes.
-   **`/shared`**: A module for shared types, constants, and Zod schemas, ensuring type safety and consistency across the frontend and backend.
-   **`/scripts`**: Stores automated deployment scripts for streamlined setup and deployment.

## Technologies Used

### Backend (`/server`)

-   **Framework**: Express.js
-   **API Layer**: tRPC
-   **Authentication**: Google OAuth
-   **Database**: MariaDB / MySQL (with Drizzle ORM)
-   **Language**: TypeScript
-   **Game Integration**: Clutch Provider

### Frontend (`/client`)

-   **Framework**: React 18
-   **Build Tool**: Vite 5
-   **UI Library**: `shadcn/ui` (built on Tailwind CSS)
-   **State Management/Data Fetching**: React Query, tRPC Client
-   **Routing**: React Router DOM
-   **Language**: TypeScript

### Shared (`/shared`)

-   **Type Management**: TypeScript
-   **Schema Validation**: Zod

## Setup and Development

To get the Kodakclout project up and running in a development environment, follow these steps:

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/damienmarx/Kodakclout.git
    cd Kodakclout
    ```

2.  **Install pnpm**: This project uses pnpm for efficient monorepo package management. If you don't have it installed, run:
    ```bash
    npm install -g pnpm
    ```

3.  **Install dependencies**: From the root of the monorepo, install all project dependencies:
    ```bash
    pnpm install
    ```

4.  **Environment Variables**: Create `.env` files for both the `server` and `client` based on their respective `.env.example` templates. Populate them with your actual credentials and configurations.

    -   `server/.env`:
        ```
        PORT=8080
        NODE_ENV=development
        CLIENT_URL=http://localhost:5173
        DATABASE_URL=mysql://user:password@localhost:3306/kodakclout
        JWT_SECRET=your_jwt_secret_here
        GOOGLE_CLIENT_ID=your_google_client_id
        GOOGLE_CLIENT_SECRET=your_google_client_secret
        CLUTCH_API_URL=http://localhost:8081 # Clutch backend now runs on 8081
        CLUTCH_API_KEY=your_clutch_api_key
        ```

    -   `client/.env`:
        ```
        VITE_API_URL=http://localhost:8080 # Frontend proxies /api to backend on 8080
        VITE_APP_NAME=Kodakclout
        ```

5.  **Database Setup**: Ensure your MariaDB/MySQL server is running and accessible. Then, run the database migrations from the `server` directory:
    ```bash
    cd server
    pnpm migrate
    cd ..
    ```
    *Note: The `pnpm migrate` command uses `drizzle-kit push:mysql` to apply schema changes to your database. Ensure your `DATABASE_URL` in `server/.env` is correctly configured.*

6.  **Start Development Servers**: From the root of the monorepo, start both the Kodakclout backend and frontend development servers concurrently:
    ```bash
    pnpm dev
    ```
    The Kodakclout frontend will be available at `http://localhost:5173` and the Kodakclout backend API at `http://localhost:8080/api`.

7.  **Start Clutch Backend**: Navigate to the `Clutch` directory and start the Clutch backend on port 8081. (Assuming you have the Clutch repository cloned and built as per its instructions):
    ```bash
    cd ../Clutch
    # Example command to start Clutch, adjust as per Clutch's README
    ./slot_linux_x64 -c degens777den.yaml web
    cd ../Kodakclout
    ```
    *Note: The `degens777den.yaml` file in the Clutch repository has been updated to use port 8081.*

## Port Alignment and Connectivity

To ensure seamless operation, the following port configurations are used:

| Component               | Development Port | Production Port (via Cloudflare) |
| :---------------------- | :--------------- | :------------------------------- |
| **Kodakclout Frontend** | `5173`           | `443` (cloutscape.org)           |
| **Kodakclout Backend**  | `8080`           | `443` (cloutscape.org/api)       |
| **Clutch Backend**      | `8081`           | `443` (games.cloutscape.org)     |

-   In **development**, the Kodakclout frontend (Vite) runs on `5173` and proxies `/api` requests to the Kodakclout backend (Express) running on `8080`. The Clutch backend runs separately on `8081`.
-   In **production**, both Kodakclout frontend and backend are served from `cloutscape.org` (port `443`) via Cloudflare Tunnel. The Clutch backend will be exposed via a subdomain, e.g., `games.cloutscape.org`, also proxied through Cloudflare Tunnel.

## Automated Deployment (Debian/Ubuntu)

The monorepo includes a zero-input automated deployment script designed for Ubuntu/Debian-based systems. This script handles system dependency installation, project setup, building, and starting the application with PM2.

To deploy your application to a production server, simply copy the entire `Kodakclout` directory to your server and run the deployment script:

```bash
cd /path/to/your/Kodakclout
sudo ./scripts/deploy.sh
```

**Key features of `deploy.sh`:**

-   **OS Detection**: Optimized for Ubuntu/Debian.
-   **Dependency Installation**: Installs Node.js, pnpm, MySQL client, git, and PM2.
-   **Project Setup**: Installs monorepo dependencies.
-   **Environment Management**: Creates `.env` files from templates if they don't exist (requires manual update of sensitive variables).
-   **Build Process**: Builds shared, client, and server modules.
-   **Database Migrations**: Runs Drizzle migrations.
-   **Process Management**: Starts the server using PM2 for production-grade process management.
-   **Health Checks**: Validates deployment by checking API endpoint.
-   **Idempotent & Safe**: Can be re-run safely without adverse effects.

## Cloudflare Dashboard Setup (for cloutscape.org and games.cloutscape.org)

For production deployment with `cloutscape.org` and `games.cloutscape.org`, you will need to configure Cloudflare Tunnels. Here's a general guide:

1.  **Install `cloudflared`**: Follow the instructions in `./scripts/setup-cloudflared.sh` to install and authenticate `cloudflared` on your Debian server.

2.  **Create a Cloudflare Tunnel for Kodakclout**: 
    -   In your Cloudflare Dashboard, navigate to **Zero Trust** > **Access** > **Tunnels**.
    -   Create a new tunnel (e.g., `kodakclout-tunnel`).
    -   Follow the steps to connect `cloudflared` on your server to this tunnel.
    -   Configure **Public Hostnames** for this tunnel:
        -   **Subdomain**: `cloutscape.org` (or leave blank for root domain)
        -   **Service**: `HTTP` -> `localhost:8080` (This routes requests for your main domain to the Kodakclout backend, which serves the frontend in production).
        -   **Subdomain**: `api.cloutscape.org`
        -   **Service**: `HTTP` -> `localhost:8080` (This routes API requests to the Kodakclout backend).

3.  **Create a Cloudflare Tunnel for Clutch**: 
    -   Create another new tunnel (e.g., `clutch-tunnel`).
    -   Connect `cloudflared` on your server to this new tunnel.
    -   Configure **Public Hostnames** for this tunnel:
        -   **Subdomain**: `games.cloutscape.org`
        -   **Service**: `HTTP` -> `localhost:8081` (This routes requests for the Clutch games to the Clutch backend).

4.  **DNS Records**: Ensure your DNS records in Cloudflare point to the respective tunnels. For `cloutscape.org`, `api.cloutscape.org`, and `games.cloutscape.org`, you will typically create `CNAME` records pointing to the tunnel's generated `cfargotunnel.com` address.

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
