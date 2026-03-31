# Cloudflare Routes & Clutch Engine Integration Guide

This guide provides the exact configuration for your Cloudflare Tunnel routes and explains how the Clutch engine is integrated into the Kodakclout platform.

## 1. Cloudflare Tunnel Routes (Ingress Rules)

In your **Cloudflare Zero Trust Dashboard** (Networks > Tunnels > `kodakclout-tunnel` > Edit > Public Hostname), you should configure the following routes to ensure all parts of the application are accessible:

| Public Hostname | Service | Path | Description |
| :--- | :--- | :--- | :--- |
| `yourdomain.com` | `http://localhost:8080` | (Leave Empty) | **Main Frontend**: Serves the React application. |
| `www.yourdomain.com` | `http://localhost:8080` | (Leave Empty) | **WWW Alias**: Redirects or serves the main site. |
| `api.yourdomain.com` | `http://localhost:8080` | `/api` | **Backend API**: Routes all tRPC and OAuth requests. |

### ⚠️ Important: WebSocket Support
The Clutch engine and real-time features require WebSockets. Ensure **WebSockets** are enabled in your Cloudflare Dashboard under **Websites** > **[yourdomain.com]** > **Network**.

---

## 2. Clutch Engine Integration

The Clutch engine is the core gaming component of Kodakclout. It is integrated as a provider-level service in the backend.

### How it Works:
1. **Provider Layer**: Located in `server/src/providers/clutch.ts`, this service communicates with the Clutch Go engine.
2. **Game Launching**: When a user clicks "Play", the backend generates a secure session token and an iframe URL.
3. **Iframe Embedding**: The frontend (`client/src/pages/GameSession.tsx`) embeds the Clutch engine via a secure iframe using the generated URL.
4. **Balance Sync**: The `balance` from the Kodakclout `users` table is passed to the Clutch engine during session initialization to ensure the user has credits to play.

### Clutch Configuration in `.env`:
Ensure these variables are correctly set in your production `.env` file:

```env
# The internal URL where the Clutch Go engine is running
CLUTCH_API_URL=http://localhost:8081 

# The public URL used for iframe embedding (should match your domain)
CLUTCH_PUBLIC_URL=https://yourdomain.com/games/clutch

# Secure key for signing game session tokens
CLUTCH_API_KEY=your-secure-clutch-key
```

### Deployment with Clutch:
The `scripts/deploy-universal-v2.sh` script automatically:
- Checks for the Clutch Go engine binary.
- Sets up the necessary SQLite database for Clutch game state.
- Configures the PM2 process to keep the engine running alongside the main server.

---

## 3. Verifying the Integration

After deployment, you can verify that both the routes and the engine are working correctly:

1. **Check API Health**: Visit `https://api.yourdomain.com/health`. It should return `{"status": "ok"}`.
2. **Check Game Listing**: Log in to your site and navigate to the Games page. You should see the list of games populated from the Clutch engine.
3. **Launch a Game**: Click on a game. If the iframe loads the game successfully, the integration is complete.

### Troubleshooting:
- **Game won't load**: Check if the Clutch process is running: `pm2 status`.
- **"Refused to display in a frame"**: Ensure your Cloudflare WAF or Nginx headers are not blocking iframe embedding from your own domain.
- **Balance not updating**: Check the `server/src/trpc/router.ts` logs to ensure the `deposit`/`withdraw` procedures are correctly updating the MariaDB `users` table.
