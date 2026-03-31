# Kodakclout Quick Start Guide

Get your Kodakclout platform up and running in minutes with our universal deployment script.

## Prerequisites

- **OS**: Debian or Ubuntu (18.04+)
- **Access**: Root or sudo privileges
- **Internet**: Active internet connection
- **Disk Space**: At least 5GB free space
- **Memory**: At least 2GB RAM recommended

## One-Command Deployment

The simplest way to deploy Kodakclout:

```bash
sudo bash /path/to/Kodakclout/scripts/deploy-universal.sh
```

Or if you're in the project directory:

```bash
cd /path/to/Kodakclout
sudo bash scripts/deploy-universal.sh
```

## What the Script Does

The universal deployment script automatically:

1. **System Setup**
   - Checks OS compatibility (Debian/Ubuntu)
   - Updates system packages
   - Installs all required dependencies

2. **Node.js & Tools**
   - Installs Node.js v22 LTS
   - Installs pnpm package manager
   - Installs PM2 process manager

3. **Application User**
   - Creates dedicated `kodakclout` user
   - Sets proper file permissions
   - Configures sudo access for PM2

4. **Environment Configuration**
   - Generates secure JWT secret
   - Creates `.env` file with defaults
   - Generates random database password

5. **Database Setup**
   - Installs MySQL server
   - Creates `kodakclout` database
   - Sets up database user with permissions
   - Runs migrations

6. **Build & Deploy**
   - Installs project dependencies
   - Builds all packages (shared, server, client)
   - Seeds initial game data
   - Starts application with PM2

7. **Web Server**
   - Configures Nginx as reverse proxy
   - Sets up port 8080 routing
   - Enables health check endpoint
   - Optionally configures SSL/TLS

8. **Verification**
   - Checks application is running
   - Verifies Nginx is operational
   - Tests health endpoint

## Post-Deployment Configuration

After the script completes, you need to configure your environment:

### 1. Update Environment Variables

```bash
sudo nano /home/kodakclout/Kodakclout/.env
```

Update these critical values:

```env
# Your domain
SERVER_URL=https://cloutscape.org
CLIENT_URL=https://cloutscape.org

# Google OAuth credentials (from https://console.cloud.google.com/)
GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-client-secret

# Clutch Engine API key
CLUTCH_API_KEY=your-api-key
```

### 2. Restart Application

```bash
sudo -u kodakclout pm2 restart kodakclout-server
```

### 3. Setup Domain

Update your DNS records to point to your server:

```
cloutscape.org    A    your.server.ip.address
www.cloutscape.org    CNAME    cloutscape.org
```

### 4. Configure SSL/TLS (Recommended)

```bash
sudo certbot certonly --nginx -d cloutscape.org -d www.cloutscape.org
```

Then update Nginx configuration:

```bash
sudo nano /etc/nginx/sites-available/kodakclout
```

Add SSL configuration:

```nginx
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name cloutscape.org www.cloutscape.org;

    ssl_certificate /etc/letsencrypt/live/cloutscape.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/cloutscape.org/privkey.pem;

    # ... rest of configuration
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name cloutscape.org www.cloutscape.org;
    return 301 https://$server_name$request_uri;
}
```

Reload Nginx:

```bash
sudo systemctl reload nginx
```

## Accessing Your Application

After deployment:

- **Web Application**: http://localhost (or your domain)
- **API Endpoint**: http://localhost/api
- **Health Check**: http://localhost/api/health
- **tRPC Endpoint**: http://localhost/api/trpc

## Useful Commands

### Application Management

```bash
# View application logs
pm2 logs kodakclout-server

# Monitor application
pm2 monit

# Restart application
pm2 restart kodakclout-server

# Stop application
pm2 stop kodakclout-server

# Start application
pm2 start kodakclout-server

# View all PM2 applications
pm2 list
```

### Database Management

```bash
# Connect to database
mysql -u kodakclout -p kodakclout

# Backup database
mysqldump -u kodakclout -p kodakclout > backup.sql

# Restore database
mysql -u kodakclout -p kodakclout < backup.sql
```

### Web Server Management

```bash
# Check Nginx status
sudo systemctl status nginx

# Reload Nginx configuration
sudo systemctl reload nginx

# Restart Nginx
sudo systemctl restart nginx

# Test Nginx configuration
sudo nginx -t
```

### View Deployment Logs

```bash
# Full deployment log
cat /var/log/kodakclout-deploy.log

# Application error log
tail -f /var/log/kodakclout-error.log

# Application output log
tail -f /var/log/kodakclout-out.log
```

## Troubleshooting

### Application Won't Start

```bash
# Check PM2 logs
pm2 logs kodakclout-server

# Check if port 8080 is in use
sudo lsof -i :8080

# Verify .env file exists and is readable
cat /home/kodakclout/Kodakclout/.env
```

### Database Connection Error

```bash
# Check MySQL is running
sudo systemctl status mysql

# Test database connection
mysql -u kodakclout -p -h localhost kodakclout

# Check database user permissions
mysql -u root -p -e "SHOW GRANTS FOR 'kodakclout'@'localhost';"
```

### Nginx Not Working

```bash
# Check Nginx configuration
sudo nginx -t

# Check if Nginx is running
sudo systemctl status nginx

# Check if port 80/443 is in use
sudo lsof -i :80
sudo lsof -i :443
```

### SSL Certificate Issues

```bash
# Check certificate status
sudo certbot certificates

# Renew certificate
sudo certbot renew

# Test certificate renewal
sudo certbot renew --dry-run
```

## Performance Tuning

### Increase Node.js Memory

Edit PM2 ecosystem configuration:

```bash
sudo nano /home/kodakclout/Kodakclout/ecosystem.config.js
```

Adjust `max_old_space_size`:

```javascript
node_args: '--max-old-space-size=1024', // Increase from 512 to 1024
```

### Database Connection Pool

Edit `.env`:

```env
# Increase connection pool size
DATABASE_POOL_SIZE=20
```

### Nginx Worker Processes

Edit Nginx configuration:

```bash
sudo nano /etc/nginx/nginx.conf
```

Adjust `worker_processes`:

```nginx
worker_processes auto; # Use all CPU cores
```

## Backup & Recovery

### Automated Backups

Create a cron job for daily backups:

```bash
sudo crontab -e
```

Add:

```cron
# Daily database backup at 2 AM
0 2 * * * mysqldump -u kodakclout -pYOUR_PASSWORD kodakclout > /backups/kodakclout-$(date +\%Y\%m\%d).sql
```

### Manual Backup

```bash
# Backup database
mysqldump -u kodakclout -p kodakclout > kodakclout-backup.sql

# Backup application files
tar -czf kodakclout-backup.tar.gz /home/kodakclout/Kodakclout
```

### Restore from Backup

```bash
# Restore database
mysql -u kodakclout -p kodakclout < kodakclout-backup.sql

# Restore application files
tar -xzf kodakclout-backup.tar.gz -C /
```

## Security Best Practices

1. **Change Default Passwords**
   ```bash
   sudo passwd kodakclout
   ```

2. **Configure Firewall**
   ```bash
   sudo ufw enable
   sudo ufw allow 22/tcp
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   ```

3. **Keep System Updated**
   ```bash
   sudo apt-get update && sudo apt-get upgrade
   ```

4. **Monitor Logs**
   ```bash
   sudo tail -f /var/log/kodakclout-error.log
   ```

5. **Regular Backups**
   - Implement automated daily backups
   - Test restore procedures regularly

## Support & Documentation

- **Main Documentation**: See `README.md`
- **Deployment Guide**: See `DEPLOYMENT.md`
- **GitHub Repository**: https://github.com/damienmarx/Kodakclout
- **Issues**: Report issues on GitHub

## Next Steps

1. Configure your domain and SSL certificate
2. Update environment variables with your credentials
3. Test the application at http://cloutscape.org
4. Configure Google OAuth for authentication
5. Set up monitoring and alerting
6. Implement backup procedures
7. Monitor application performance

Congratulations! Your Kodakclout platform is now deployed and ready for use!
