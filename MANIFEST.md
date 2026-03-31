# Kodakclout Platform Manifest

This document provides a complete inventory of all features, infrastructure, and documentation currently included in the Kodakclout repository.

## 1. Core Application Features

### 🔐 Authentication & Security
- **Google OAuth 2.0**: Full integration with user creation and session management.
- **JWT Sessions**: Secure, cookie-based session handling.
- **Password Hashing**: Industry-standard `bcrypt` with 12 salt rounds.
- **Protected Routes**: tRPC middleware for authenticated-only access.
- **Type-Safe API**: End-to-end type safety using tRPC and Zod.

### 💰 Wallet & Credits System
- **User Balance**: Real-time balance tracking in the database.
- **Deposit/Withdraw**: Secure tRPC procedures for managing funds.
- **UI Integration**: Persistent balance display in the navigation bar across all pages.
- **Insufficient Funds Checks**: Server-side validation for all transactions.

### 🎮 Game Engine & Discovery
- **Clutch Go Integration**: Provider-level support for the Clutch gaming engine.
- **Game Lobby**: Dynamic game listing with category filtering and search.
- **Game Launching**: Secure session generation for launching games.
- **Metadata Management**: Comprehensive game info (slug, provider, category, status).

### 🛠️ Admin Panel
- **User Management**: List users, view details, and update balances.
- **Game Management**: List games, update metadata, and toggle active status.
- **Analytics**: Platform-wide statistics (total users, total games).

---

## 2. Infrastructure & DevOps

### 🚀 Universal Deployment (v2)
- **Debian/Ubuntu Support**: Optimized for standard Linux environments.
- **MariaDB Integration**: Pre-configured with default password "maria".
- **Port 8080 Standardization**: All services and proxies aligned to port 8080.
- **Automatic .env Setup**: Secure generation of JWT secrets and database credentials.
- **PM2 Process Management**: Production-ready process monitoring and clustering.
- **Nginx Reverse Proxy**: Pre-configured routing for API and Frontend.

### ☁️ Cloudflare Tunnel & Self-Healing
- **Automatic Installation**: Scripted setup of `cloudflared`.
- **Continuous Monitoring**: Health checks every 60 seconds.
- **Self-Healing**: Automatic restart on failure with exponential backoff.
- **State Tracking**: Logging and status reporting for the tunnel.
- **Adaptive Binary Support**: Works on x86_64 and ARM64 architectures.

### 🗄️ Database & Seeding
- **Drizzle ORM**: Type-safe database schema and migrations.
- **Migration Scripts**: Automated schema updates.
- **Game Seeder**: Script to populate the database with sample game data.

---

## 3. Documentation & Guides

| File | Purpose |
|------|---------|
| `README_UPDATED.md` | Main project overview, tech stack, and features. |
| `QUICK_START.md` | One-command deployment and post-setup steps. |
| `DEPLOYMENT.md` | Detailed manual deployment and production guide. |
| `CLOUDFLARE_SETUP.md` | Technical guide for the self-healing tunnel script. |
| `CLOUDFLARE_DASHBOARD.md` | Step-by-step Cloudflare web dashboard configuration. |
| `TODO.md` | Development roadmap and future features. |
| `.env.example` | Template for all required environment variables. |

---

## 4. Technical Stack Summary

- **Frontend**: React 18, TypeScript, Vite, TailwindCSS, Lucide Icons.
- **Backend**: Node.js 22, Express, tRPC, Drizzle ORM.
- **Database**: MariaDB / MySQL 8.
- **DevOps**: pnpm, PM2, Nginx, Cloudflare Tunnel, Certbot.
- **Auth**: Google OAuth, JWT, bcrypt.

---

## 5. Repository Status
- **Total Commits**: 82
- **Branch**: `main`
- **Build Status**: ✅ All packages (shared, server, client) build successfully.
- **Manus Dependencies**: ❌ None (Pure open-source stack).
