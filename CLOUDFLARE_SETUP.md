# Cloudflare Tunnel Setup & Self-Healing Guide

This guide explains how to set up and manage Cloudflare Tunnel (cloudflared) with automatic self-healing capabilities for the Kodakclout platform.

## Overview

The Kodakclout deployment includes automatic Cloudflare Tunnel integration with:

- **Automatic Health Checks**: Continuous monitoring of tunnel status
- **Self-Healing**: Automatic restart on failure with exponential backoff
- **Adaptive Environment Detection**: Works across different Linux distributions
- **PM2 Integration**: Process management and monitoring
- **Comprehensive Logging**: Detailed logs for troubleshooting

## Prerequisites

- Cloudflare account with domain
- Cloudflare Tunnel credentials
- Debian/Ubuntu server
- Root or sudo access

## Quick Start

### 1. Deploy with Cloudflare Tunnel

```bash
sudo bash scripts/deploy-universal-v2.sh --with-cloudflare --domain cloutscape.org
```

This will:
- Install cloudflared
- Configure tunnel
- Set up automatic health checks
- Enable self-healing

### 2. Authenticate with Cloudflare

```bash
cloudflared tunnel login
```

Follow the browser prompt to authenticate and select your domain.

### 3. Create a Tunnel

```bash
cloudflared tunnel create kodakclout-tunnel
```

This creates a tunnel and saves credentials to `~/.cloudflared/`.

### 4. Configure Tunnel

Edit `/etc/cloudflared/config.yml`:

```yaml
tunnel: kodakclout-tunnel
credentials-file: /root/.cloudflared/kodakclout-tunnel.json
logfile: /var/log/kodakclout/cloudflared-tunnel.log
loglevel: info

ingress:
  - hostname: cloutscape.org
    service: http://localhost:8080
  - hostname: www.cloutscape.org
    service: http://localhost:8080
  - service: http_status:404
```

### 5. Start the Tunnel

```bash
bash scripts/cloudflared-health-check.sh start
```

## Health Check Script

The `cloudflared-health-check.sh` script provides comprehensive monitoring and self-healing.

### Commands

```bash
# Setup cloudflared (install, configure, start)
bash scripts/cloudflared-health-check.sh setup

# Start tunnel
bash scripts/cloudflared-health-check.sh start

# Stop tunnel
bash scripts/cloudflared-health-check.sh stop

# Restart tunnel
bash scripts/cloudflared-health-check.sh restart

# Check tunnel status
bash scripts/cloudflared-health-check.sh status

# Run health check
bash scripts/cloudflared-health-check.sh check

# Run self-healing procedure
bash scripts/cloudflared-health-check.sh heal

# Start continuous monitoring (runs in background)
bash scripts/cloudflared-health-check.sh monitor
```

### Health Check Details

The health check verifies:

1. **Process Status**: Is cloudflared running?
2. **Application Health**: Is the backend responding?
3. **Tunnel Connectivity**: Is the tunnel connected?

If any check fails, the self-healing procedure is triggered.

### Self-Healing Process

When a failure is detected:

1. Stop the cloudflared process
2. Backup current configuration
3. Wait 30 seconds (configurable backoff)
4. Restart cloudflared
5. Verify tunnel is healthy

If restart fails, it retries up to 5 times with increasing backoff.

## Monitoring

### View Tunnel Status

```bash
bash scripts/cloudflared-health-check.sh status
```

Output example:
```
════════════════════════════════════════════════════════════════
Cloudflared Status Report
════════════════════════════════════════════════════════════════

✓ cloudflared: INSTALLED
✓ Process: RUNNING
✓ Configuration: EXISTS
✓ Tunnel: HEALTHY

Recent logs (last 10 lines):
  [2024-03-31 12:00:00] [i] Checking tunnel status...
  [2024-03-31 12:00:00] [✓] cloudflared process is running
  [2024-03-31 12:00:01] [✓] Tunnel status: HEALTHY
```

### View Logs

```bash
# Health check logs
tail -f /var/log/kodakclout/cloudflared-health.log

# Tunnel logs
tail -f /var/log/kodakclout/cloudflared-tunnel.log

# PM2 logs
pm2 logs cloudflared
```

### Continuous Monitoring

Start the monitoring loop:

```bash
bash scripts/cloudflared-health-check.sh monitor
```

This runs continuous health checks every 60 seconds and auto-heals on failure.

For background monitoring, use PM2:

```bash
pm2 start scripts/cloudflared-health-check.sh --name "cloudflared-monitor" -- monitor
pm2 save
```

## Configuration

### Health Check Interval

Edit `scripts/cloudflared-health-check.sh`:

```bash
HEALTH_CHECK_INTERVAL=60  # seconds
```

### Max Restart Attempts

```bash
MAX_RESTART_ATTEMPTS=5
```

### Restart Backoff

```bash
RESTART_BACKOFF=30  # seconds
```

## Troubleshooting

### Tunnel Won't Start

```bash
# Check cloudflared installation
which cloudflared
cloudflared --version

# Check configuration
cat /etc/cloudflared/config.yml

# Check credentials
ls -la ~/.cloudflared/

# View detailed logs
bash scripts/cloudflared-health-check.sh status
```

### Authentication Issues

```bash
# Re-authenticate with Cloudflare
cloudflared tunnel login

# Verify credentials
cloudflared tunnel list
```

### Health Check Failing

```bash
# Run manual health check
bash scripts/cloudflared-health-check.sh check

# Check application health
curl http://localhost:8080/api/health

# Check if backend is running
pm2 status
```

### Self-Healing Not Working

```bash
# Check if script has execute permissions
ls -la scripts/cloudflared-health-check.sh

# Run manual heal
bash scripts/cloudflared-health-check.sh heal

# Check logs
tail -50 /var/log/kodakclout/cloudflared-health.log
```

## Advanced Configuration

### Custom Domain Routing

Edit `/etc/cloudflared/config.yml`:

```yaml
ingress:
  # API subdomain
  - hostname: api.cloutscape.org
    service: http://localhost:8080/api
  
  # Main domain
  - hostname: cloutscape.org
    service: http://localhost:8080
  
  # Wildcard
  - hostname: "*.cloutscape.org"
    service: http://localhost:8080
  
  # Catch-all
  - service: http_status:404
```

### Custom Health Check Endpoint

Modify the health check script to use a custom endpoint:

```bash
# In cloudflared-health-check.sh
if curl -s http://localhost:$APP_PORT/api/custom-health | grep -q "healthy"; then
    log_success "Custom health check passed"
fi
```

### Systemd Service

The deployment script creates a systemd service:

```bash
# Start tunnel
sudo systemctl start cloudflared

# Stop tunnel
sudo systemctl stop cloudflared

# Check status
sudo systemctl status cloudflared

# View logs
sudo journalctl -u cloudflared -f
```

### PM2 Management

The deployment script can set up PM2 for cloudflared:

```bash
# Start with PM2
pm2 start scripts/cloudflared-health-check.sh --name "cloudflared" -- start

# Monitor
pm2 monit

# Logs
pm2 logs cloudflared
```

## Security Best Practices

1. **Credentials**: Keep `~/.cloudflared/` permissions restricted
   ```bash
   chmod 700 ~/.cloudflared/
   chmod 600 ~/.cloudflared/*.json
   ```

2. **Firewall**: Restrict direct access to port 8080
   ```bash
   sudo ufw deny 8080/tcp
   ```

3. **Logging**: Monitor logs for suspicious activity
   ```bash
   grep "error\|fail" /var/log/kodakclout/cloudflared-health.log
   ```

4. **Backups**: Backup tunnel credentials
   ```bash
   tar -czf cloudflared-backup.tar.gz ~/.cloudflared/
   ```

## Performance Optimization

### Increase Worker Threads

Edit `/etc/cloudflared/config.yml`:

```yaml
# Add to config
workers: 4
```

### Connection Pooling

```yaml
# Increase connection pool
max-connections: 100
```

### Caching

```yaml
# Enable caching for static content
cache-ttl: 3600
```

## Monitoring & Alerting

### Email Alerts

Create a wrapper script for email notifications:

```bash
#!/bin/bash
if ! bash scripts/cloudflared-health-check.sh check; then
    echo "Cloudflared health check failed" | mail -s "Alert: Kodakclout Tunnel Down" admin@cloutscape.org
fi
```

Schedule with cron:

```bash
*/5 * * * * bash /path/to/alert-script.sh
```

### Slack Notifications

```bash
#!/bin/bash
if ! bash scripts/cloudflared-health-check.sh check; then
    curl -X POST -H 'Content-type: application/json' \
        --data '{"text":"Cloudflared health check failed"}' \
        YOUR_SLACK_WEBHOOK_URL
fi
```

## Updating Cloudflared

```bash
# Update via package manager
sudo apt-get update
sudo apt-get upgrade cloudflared

# Or download latest binary
curl -L https://github.com/cloudflare/cloudflared/releases/download/2024.1.0/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared
chmod +x /usr/local/bin/cloudflared

# Restart tunnel
bash scripts/cloudflared-health-check.sh restart
```

## Rollback

If issues occur after updates:

```bash
# Restore from backup
cp /etc/cloudflared/config.yml.backup.TIMESTAMP /etc/cloudflared/config.yml

# Restart tunnel
bash scripts/cloudflared-health-check.sh restart
```

## Support

For issues or questions:

1. Check logs: `/var/log/kodakclout/cloudflared-health.log`
2. Run status check: `bash scripts/cloudflared-health-check.sh status`
3. Review Cloudflare documentation: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/

## Additional Resources

- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Cloudflared GitHub](https://github.com/cloudflare/cloudflared)
- [Kodakclout Deployment Guide](./DEPLOYMENT.md)
- [Kodakclout Quick Start](./QUICK_START.md)
