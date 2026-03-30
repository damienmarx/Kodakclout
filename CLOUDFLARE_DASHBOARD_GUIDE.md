# ☁️ Cloudflare Dashboard Setup Guide – Kodakclout

This guide provides the exact settings required in your Cloudflare Dashboard to ensure the **Kodakclout Platform** and **Clutch Games Engine** function perfectly with the automated self-healing scripts.

---

## 1. Cloudflare Tunnel (Zero Trust)
In your Cloudflare Zero Trust dashboard (**Networks > Tunnels**), locate or create your tunnel (e.g., `kodakclout-main-tunnel`).

### **Public Hostname Settings**
Add these three hostnames to your tunnel. The automated script will attempt to repair these if they are missing.

| Public Hostname | Service Type | URL (Internal) | Description |
| :--- | :--- | :--- | :--- |
| `cloutscape.org` | `HTTP` | `http://localhost:8080` | Main Frontend & App |
| `api.cloutscape.org` | `HTTP` | `http://localhost:8080` | Backend API Access |
| `games.cloutscape.org` | `HTTP` | `http://localhost:8081` | Clutch Games Engine |

---

## 2. DNS Records
Cloudflare automatically creates these **CNAME** records when you add the hostnames to your tunnel. Your DNS tab should look like this:

| Type | Name | Content | Proxy Status |
| :--- | :--- | :--- | :--- |
| `CNAME` | `cloutscape.org` | `[tunnel-id].cfargotunnel.com` | 🟧 Proxied |
| `CNAME` | `api` | `[tunnel-id].cfargotunnel.com` | 🟧 Proxied |
| `CNAME` | `games` | `[tunnel-id].cfargotunnel.com` | 🟧 Proxied |

---

## 3. Critical Security & Network Settings
To prevent the casino games (iframes) from being blocked, ensure these settings are active in your main Cloudflare Dashboard:

### **SSL/TLS Settings**
- **Mode:** `Full (Strict)`
- **Always Use HTTPS:** `On`

### **Network Settings**
- **WebSockets:** `On` (Required for real-time game state updates)
- **gRPC:** `On` (Optional but recommended)

### **Content Security Policy (CSP)**
Ensure you do not have a dashboard-level CSP that blocks `games.cloutscape.org` from being loaded as a `frame-src` on `cloutscape.org`.

---

## 4. API Token Permissions
For the **Adaptive Status Check & Repair** script (`setup-cloudflared-v2.sh`) to work, your `CLOUDFLARE_API_TOKEN` must have these permissions:

- **Account** | **Cloudflare Tunnel** | **Edit**
- **Zone** | **DNS** | **Edit**
- **Zone** | **Zone** | **Read**

---

## 5. Troubleshooting the Dashboard
If your site shows a `502 Bad Gateway` or `1033 Tunnel Not Found`:
1.  Check `pm2 status` to ensure `kodakclout` and `clutch-engine` are running locally.
2.  Run `./scripts/setup-cloudflared-v2.sh` to trigger an automated repair.
3.  Verify the `Tunnel ID` in your dashboard matches the ID in `/etc/cloudflared/config.yml`.

---
*Maintained by Damien Marx.*
