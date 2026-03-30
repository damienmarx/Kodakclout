# Kodakclout: Future Development Roadmap

This document outlines the prioritized next steps for enhancing the Kodakclout platform, building upon the currently fully functional core features.

## 🚀 Phase 1: Core Functionality & Security (Completed)

*   **Monorepo Build System**: Fully operational, including shared folder fixes and cross-package resolution.
*   **Hardened Deployment**: `deploy.sh` script is robust, Debian-compatible, with Go 1.25+ auto-provisioning and MariaDB self-healing.
*   **Real Game Integration**: Node.js backend fully integrated with Clutch Go engine for game listing and session launching.
*   **Dynamic Game Lobby**: Frontend displays and launches games from Clutch via secure iframes.
*   **Hybrid Database Layer**: MariaDB for main app data, SQLite for Clutch game state.
*   **Secure Authentication Keys**: Production-grade JWT keys generated and configured for Clutch.

## 🎯 Phase 2: Monetization & User Experience (Next Steps)

### 1. Wallet & Credits System

**Goal**: Enable users to manage in-game currency and interact with game mechanics that require a balance.

*   **Task**: Add a `balance` column to the `users` table in `server/src/db/schema.ts`.
*   **Task**: Implement tRPC procedures for "Deposit" and "Withdraw" operations (initially simulated).
*   **Task**: Integrate the user's balance with the Clutch engine when launching a game session.
*   **Task**: Display user's current balance prominently in the frontend UI.

### 2. Authentication Hardening (Google OAuth)

**Goal**: Provide a seamless and secure one-click login experience for users.

*   **Task**: Install and configure `google-auth-library` in the Node.js backend.
*   **Task**: Replace the mock Google OAuth routes in `server/src/index.ts` with the actual implementation.
*   **Task**: Ensure user sessions are correctly created and managed in both the Kodakclout database and the Clutch engine upon successful Google OAuth.
*   **Task**: Implement session refresh and token management for persistent logins.

### 3. Game Content & Discovery

**Goal**: Enhance the game library and improve user experience for finding new games.

*   **Task**: Create a migration or seed script to populate the `games` table with comprehensive metadata (e.g., RTP, volatility, themes) for all games available in the Clutch `game/` directory.
*   **Task**: Develop an admin interface or CLI tool to easily add/remove/update game metadata.
*   **Task**: Implement advanced filtering and sorting options in the frontend game lobby (e.g., by provider, category, popularity).
*   **Task**: Design and integrate high-quality game thumbnails and promotional assets.

### 4. Admin Panel

**Goal**: Provide tools for platform administrators to manage users, games, and system settings.

*   **Task**: Develop a secure, protected route for an admin dashboard in the Node.js backend.
*   **Task**: Create frontend UI for user management (view, edit, ban users).
*   **Task**: Create frontend UI for game management (activate/deactivate games, update metadata).
*   **Task**: Implement basic analytics and monitoring views.

## 💡 Future Considerations

*   **Leaderboards & Achievements**: Drive engagement with competitive features.
*   **Promotions & Bonuses**: Implement a system for offering in-game bonuses and promotions.
*   **Multi-Currency Support**: Allow for different fiat or cryptocurrency options.
*   **Real-time Chat**: Integrate a chat system for player interaction.
*   **Dockerization**: Containerize the entire stack for easier deployment and scaling across different environments.
