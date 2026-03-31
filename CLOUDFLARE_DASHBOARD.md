# Cloudflare Dashboard Configuration Guide

This guide details the specific settings and configurations you should have in your Cloudflare Dashboard to properly support the Kodakclout platform.

## 1. Zero Trust Dashboard (Tunnels)

Navigate to **Zero Trust** > **Networks** > **Tunnels**.

### Tunnel Details
- **Name**: `kodakclout-tunnel` (or your preferred name)
- **Status**: Should show **HEALTHY** (Green) when the script is running.
- **Connector**: Should show your server's hostname and IP.

### Public Hostnames (Ingress Rules)
You should have at least two public hostnames configured:

| Public Hostname | Service | Path |
|-----------------|---------|------|
| `cloutscape.org` | `http://localhost:8080` | (empty) |
| `www.cloutscape.org` | `http://localhost:8080` | (empty) |
| `api.cloutscape.org` | `http://localhost:8080` | `/api` (optional) |

## 2. DNS Settings

Navigate to **Websites** > **[cloutscape.org]** > **DNS**.

### Required Records
Cloudflare Tunnels automatically manage these CNAME records. Ensure they are **Proxied** (Orange Cloud):

| Type | Name | Content | Proxy Status |
|------|------|---------|--------------|
| CNAME | `cloutscape.org` | `[tunnel-id].cfargotunnel.com` | Proxied |
| CNAME | `www` | `cloutscape.org` | Proxied |
| CNAME | `api` | `cloutscape.org` | Proxied |

## 3. SSL/TLS Settings

Navigate to **Websites** > **[cloutscape.org]** > **SSL/TLS**.

- **Encryption Mode**: Set to **Full** or **Full (Strict)**.
  - *Note*: Since the tunnel handles the encryption between Cloudflare and your server, "Full" is usually sufficient.
- **Always Use HTTPS**: **On**.
- **HSTS**: **On** (Recommended for production).

## 4. Security & WAF (Web Application Firewall)

Navigate to **Websites** > **[cloutscape.org]** > **Security** > **WAF**.

### Recommended Rules
1. **Block Known Bots**: Enable the "Bot Fight Mode".
2. **Rate Limiting**: 
   - **Path**: `/api/*`
   - **Action**: Block or Challenge if requests exceed 100 per minute from a single IP.
3. **Challenge Non-Standard Countries**: If your platform is region-specific, add a "JS Challenge" for traffic from unexpected countries.

## 5. Caching

Navigate to **Websites** > **[cloutscape.org]** > **Caching** > **Configuration**.

- **Caching Level**: **Standard**.
- **Browser Cache TTL**: **4 hours** (or as preferred).
- **Development Mode**: Keep **Off** unless debugging frontend changes.

## 6. Network Settings

Navigate to **Websites** > **[cloutscape.org]** > **Network**.

- **WebSockets**: **On** (Required for real-time game features).
- **gRPC**: **On** (Optional, but good for performance).
- **HTTP/3 (with QUIC)**: **On**.

## 7. Access (Optional but Recommended)

Navigate to **Zero Trust** > **Access** > **Applications**.

- **Admin Panel Protection**: 
  - Create an application for `cloutscape.org/admin` (if implemented).
  - Add a policy to allow only your email address via OTP or Google Workspace.

## 8. Workers & Pages (Optional)

If you decide to move the frontend to Cloudflare Pages:
- **Build Command**: `pnpm --filter @kodakclout/client build`
- **Output Directory**: `client/dist`

---

## Troubleshooting Dashboard Issues

### "Tunnel not found"
- Ensure the `tunnel-id` in your local `config.yml` matches the ID shown in the Zero Trust dashboard.

### "502 Bad Gateway"
- This usually means `cloudflared` is running but cannot reach your local service at `http://localhost:8080`.
- Check if the server is running: `pm2 status`.

### "SSL Handshake Error"
- Ensure your SSL/TLS mode is not set to "Flexible" if you are using a tunnel; "Full" is required.

### "Too Many Redirects"
- This happens if "Always Use HTTPS" is on in Cloudflare but your server is also trying to redirect to HTTPS. Let Cloudflare handle the redirect.
