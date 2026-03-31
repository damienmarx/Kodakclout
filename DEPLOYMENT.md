# Kodakclout Deployment Guide

This guide provides step-by-step instructions for deploying the Kodakclout platform to production.

## Prerequisites

- **Node.js**: v18+ (tested with v22.13.0)
- **pnpm**: v8+ (package manager)
- **MySQL/MariaDB**: v8.0+ (database)
- **Go**: v1.25+ (for Clutch engine integration)
- **Domain**: A registered domain for your deployment

## Environment Setup

### 1. Clone the Repository

```bash
git clone https://github.com/damienmarx/Kodakclout.git
cd Kodakclout
```

### 2. Install Dependencies

```bash
pnpm install
```

### 3. Configure Environment Variables

Copy the example environment file and update it with your production values:

```bash
cp .env.example .env
```

Edit `.env` with your configuration:

```env
# Database
DATABASE_URL=mysql://user:password@db-host:3306/kodakclout

# Server
PORT=8080
NODE_ENV=production
SERVER_URL=https://api.yourdomain.com
CLIENT_URL=https://yourdomain.com

# JWT
JWT_SECRET=<generate-a-secure-random-key>
PASSWORD_SALT_ROUNDS=12

# Google OAuth
GOOGLE_CLIENT_ID=<your-google-client-id>
GOOGLE_CLIENT_SECRET=<your-google-client-secret>

# Clutch Engine
CLUTCH_API_URL=https://api.clutch.io
CLUTCH_API_KEY=<your-clutch-api-key>
```

### 4. Database Setup

Run migrations to set up the database schema:

```bash
pnpm --filter @kodakclout/server run migrate
```

Or manually create the database:

```bash
mysql -u root -p -e "CREATE DATABASE kodakclout CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
```

## Building for Production

### 1. Build All Packages

```bash
pnpm build
```

This will:
- Build the shared package
- Build the server package
- Build the client package (Vite)

### 2. Verify Build Output

```bash
ls -la server/dist
ls -la client/dist
```

## Running in Production

### 1. Start the Server

```bash
NODE_ENV=production node server/dist/server/src/index.js
```

Or use a process manager like PM2:

```bash
pm2 start server/dist/server/src/index.js --name "kodakclout-server" --env NODE_ENV=production
```

### 2. Verify Server is Running

```bash
curl http://localhost:8080/api/health
```

Expected response:
```json
{"status":"ok","ts":1234567890}
```

## Docker Deployment (Optional)

### 1. Create Dockerfile

```dockerfile
FROM node:22-alpine

WORKDIR /app

# Install pnpm
RUN npm install -g pnpm

# Copy package files
COPY pnpm-lock.yaml pnpm-workspace.yaml ./
COPY shared/package.json shared/
COPY server/package.json server/
COPY client/package.json client/

# Install dependencies
RUN pnpm install --frozen-lockfile

# Copy source code
COPY . .

# Build all packages
RUN pnpm build

# Expose port
EXPOSE 8080

# Start server
CMD ["node", "server/dist/server/src/index.js"]
```

### 2. Build and Run Docker Image

```bash
docker build -t kodakclout:latest .
docker run -p 8080:8080 --env-file .env kodakclout:latest
```

## Nginx Configuration (Reverse Proxy)

Create `/etc/nginx/sites-available/kodakclout`:

```nginx
upstream kodakclout_backend {
    server localhost:8080;
}

server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name yourdomain.com www.yourdomain.com;

    ssl_certificate /path/to/certificate.crt;
    ssl_certificate_key /path/to/private.key;

    client_max_body_size 10M;

    # API and tRPC routes
    location /api {
        proxy_pass http://kodakclout_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Frontend assets
    location / {
        proxy_pass http://kodakclout_backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

Enable the site:

```bash
sudo ln -s /etc/nginx/sites-available/kodakclout /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

## SSL/TLS Certificate Setup

Use Let's Encrypt with Certbot:

```bash
sudo apt-get install certbot python3-certbot-nginx
sudo certbot certonly --nginx -d yourdomain.com -d www.yourdomain.com
```

## Monitoring and Logs

### View Server Logs

```bash
pm2 logs kodakclout-server
```

### Monitor Performance

```bash
pm2 monit
```

### Database Health Check

```bash
mysql -u user -p -e "SELECT 1 FROM users LIMIT 1;"
```

## Troubleshooting

### Database Connection Issues

```bash
# Test connection
mysql -h db-host -u user -p -e "SELECT 1;"

# Check DATABASE_URL format
# mysql://user:password@host:port/database
```

### OAuth Not Working

1. Verify `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` are correct
2. Check redirect URI matches in Google Console: `https://yourdomain.com/api/oauth/google/callback`
3. Ensure `SERVER_URL` and `CLIENT_URL` are set correctly

### Build Failures

```bash
# Clear cache and reinstall
rm -rf node_modules pnpm-lock.yaml
pnpm install

# Rebuild
pnpm build
```

## Scaling Considerations

- **Database**: Use read replicas for high-traffic scenarios
- **Load Balancing**: Use multiple server instances behind a load balancer
- **Caching**: Implement Redis for session and game data caching
- **CDN**: Serve static assets through a CDN (Cloudflare, AWS CloudFront)

## Security Best Practices

1. **Environment Variables**: Never commit `.env` files; use `.env.example` as template
2. **JWT Secret**: Generate a strong, random JWT_SECRET
3. **HTTPS**: Always use HTTPS in production
4. **CORS**: Configure CORS origins appropriately
5. **Database**: Use strong passwords and limit database access to application servers
6. **Rate Limiting**: Implement rate limiting on API endpoints
7. **Input Validation**: All inputs are validated using Zod schemas

## Backup and Recovery

### Database Backup

```bash
mysqldump -u user -p kodakclout > backup.sql
```

### Restore from Backup

```bash
mysql -u user -p kodakclout < backup.sql
```

## Support

For issues or questions, refer to the main README.md or contact the development team.
