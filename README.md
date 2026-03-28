# Kodakclout Monorepo

Welcome to the Kodakclout monorepo, a comprehensive platform for a premium casino experience. This project is built with a modern tech stack, designed for scalability, performance, and ease of deployment. It features a robust backend, a polished frontend, and a shared module for common types and schemas, all orchestrated within a monorepo structure.

## Project Structure

The monorepo is organized into the following key directories:

- **`/server`**: Contains the backend application, built with Express, tRPC, Google OAuth, and MySQL (via Drizzle ORM). It also includes a Clutch game provider integration.
- **`/client`**: Houses the frontend application, developed using React 18, Vite 5, and `shadcn/ui` components. It interacts with the backend via a tRPC client.
- **`/shared`**: A module for shared types, constants, and Zod schemas, ensuring type safety and consistency across the frontend and backend.
- **`/scripts`**: Stores automated deployment scripts for streamlined setup and deployment.

## Technologies Used

### Backend (`/server`)

- **Framework**: Express.js
- **API Layer**: tRPC
- **Authentication**: Google OAuth
- **Database**: MariaDB / MySQL (with Drizzle ORM)
- **Language**: TypeScript
- **Game Integration**: Clutch Provider

### Frontend (`/client`)

- **Framework**: React 18
- **Build Tool**: Vite 5
- **UI Library**: `shadcn/ui` (built on Tailwind CSS)
- **State Management/Data Fetching**: React Query, tRPC Client
- **Routing**: React Router DOM
- **Language**: TypeScript

### Shared (`/shared`)

- **Type Management**: TypeScript
- **Schema Validation**: Zod

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
        CLIENT_URL=https://cloutscape.org
        DATABASE_URL=mysql://user:password@localhost:3306/kodakclout
        JWT_SECRET=your_jwt_secret_here
        GOOGLE_CLIENT_ID=your_google_client_id
        GOOGLE_CLIENT_SECRET=your_google_client_secret
        CLUTCH_API_URL=https://api.clutch.io
        CLUTCH_API_KEY=your_clutch_api_key
        ```

    -   `client/.env`:
        ```
        VITE_API_URL=https://cloutscape.org
        VITE_APP_NAME=Kodakclout
        ```

5.  **Database Setup**: Ensure your MariaDB/MySQL server is running and accessible. Then, run the database migrations from the `server` directory:
    ```bash
    cd server
    pnpm migrate
    cd ..
    ```
    *Note: The `pnpm migrate` command uses `drizzle-kit push:mysql` to apply schema changes to your database. Ensure your `DATABASE_URL` in `server/.env` is correctly configured.*

6.  **Start Development Servers**: From the root of the monorepo, start both the backend and frontend development servers concurrently:
    ```bash
    pnpm dev
    ```
    The frontend will typically be available at `https://cloutscape.org` and the backend API at `https://cloutscape.org/api` (proxied via port 8080).

## Automated Deployment

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

## Path Aliases

Path aliases are configured for improved import readability and maintainability:

-   `@/`: Maps to `client/src`
-   `@server/`: Maps to `server/src`
-   `@shared/`: Maps to `shared/src`

## Branding

All branding within the project is for **Kodakclout**, owned by Damien. All references to AI, Manus, Assistants, or generated code have been removed to maintain a consistent brand identity.

## Final Deliverables

This monorepo provides:

-   A fully working, production-grade monorepo structure.
-   Clean, modern, and modular code.
-   All imports and routes correctly resolved and functional.
-   Full integration with the Clutch game provider.
-   A fully functional and polished frontend with a casino lobby UI.
-   A robust backend supporting authentication, game data, and launch mechanisms.
-   A fully automated, zero-input deployment script for end-to-end setup and deployment.
-   Clear instructions for both development and production environments.

---

*This project was developed by Damien for Kodakclout.*
