# MariaDB Setup Guide for Kodakclout on Debian

This guide walks you through setting up MariaDB for Kodakclout on a Debian server.

## 1. Install MariaDB Server

```bash
sudo apt-get update
sudo apt-get install -y mariadb-server mariadb-client
```

## 2. Start and Enable MariaDB

```bash
# Start the service
sudo systemctl start mariadb

# Enable on boot
sudo systemctl enable mariadb

# Verify it's running
sudo systemctl status mariadb
```

## 3. Secure MariaDB (Initial Setup)

Run the security script:

```bash
sudo mysql_secure_installation
```

**Recommended answers:**
- Switch to unix_socket authentication? → **N** (use password auth)
- Remove anonymous users? → **Y**
- Disable root login remotely? → **Y**
- Remove test database? → **Y**
- Reload privilege tables? → **Y**

## 4. Create Kodakclout Database & User

Log in as root:

```bash
sudo mariadb -u root
```

Then run these SQL commands:

```sql
-- Create database
CREATE DATABASE IF NOT EXISTS kodakclout;

-- Create user with password
CREATE USER IF NOT EXISTS 'clout_user'@'localhost' IDENTIFIED BY 'clout_pass';

-- Grant all privileges on kodakclout database
GRANT ALL PRIVILEGES ON kodakclout.* TO 'clout_user'@'localhost';

-- Flush privileges to apply changes
FLUSH PRIVILEGES;

-- Exit
EXIT;
```

## 5. Verify the Setup

Test the connection:

```bash
mariadb -u clout_user -p -h localhost kodakclout
```

When prompted, enter the password: `clout_pass`

You should see the `MariaDB [kodakclout]>` prompt. Type `EXIT;` to quit.

## 6. Update Kodakclout .env

Edit `server/.env`:

```bash
nano server/.env
```

Set the DATABASE_URL:

```env
DATABASE_URL=mysql://clout_user:clout_pass@127.0.0.1:3306/kodakclout
```

**Important:** Use `127.0.0.1` (not `localhost`) to avoid socket connection issues.

## 7. Run Database Migrations

From the Kodakclout root directory:

```bash
cd server
pnpm migrate
```

This creates all the tables (users, sessions, games) using Drizzle ORM.

## 8. Verify Tables Were Created

```bash
mariadb -u clout_user -p kodakclout -e "SHOW TABLES;"
```

You should see:
- `games`
- `sessions`
- `users`

## Troubleshooting

### "Access denied for user 'clout_user'@'localhost'"

**Solution:** Use `127.0.0.1` instead of `localhost` in DATABASE_URL:

```env
DATABASE_URL=mysql://clout_user:clout_pass@127.0.0.1:3306/kodakclout
```

### "Can't connect to local MySQL server through socket"

**Solution:** Ensure MariaDB is running:

```bash
sudo systemctl restart mariadb
sudo systemctl status mariadb
```

### "Unknown database 'kodakclout'"

**Solution:** Create the database again:

```bash
sudo mariadb -u root -e "CREATE DATABASE IF NOT EXISTS kodakclout;"
```

### "Permission denied" during migration

**Solution:** Ensure the user has all privileges:

```bash
sudo mariadb -u root -e "GRANT ALL PRIVILEGES ON kodakclout.* TO 'clout_user'@'localhost'; FLUSH PRIVILEGES;"
```

## Backup & Restore

### Backup the database:

```bash
mysqldump -u clout_user -p kodakclout > kodakclout_backup.sql
```

### Restore from backup:

```bash
mariadb -u clout_user -p kodakclout < kodakclout_backup.sql
```

## Automated Daily Backups (Cron)

Create a backup script:

```bash
sudo nano /usr/local/bin/backup-kodakclout.sh
```

Add:

```bash
#!/bin/bash
BACKUP_DIR="/home/ubuntu/backups"
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mysqldump -u clout_user -pclout_pass kodakclout > "$BACKUP_DIR/kodakclout_$TIMESTAMP.sql"
# Keep only last 7 days of backups
find "$BACKUP_DIR" -name "kodakclout_*.sql" -mtime +7 -delete
```

Make it executable:

```bash
sudo chmod +x /usr/local/bin/backup-kodakclout.sh
```

Add to crontab (daily at 2 AM):

```bash
sudo crontab -e
```

Add this line:

```
0 2 * * * /usr/local/bin/backup-kodakclout.sh
```

## Performance Tuning (Optional)

For production, edit `/etc/mysql/mariadb.conf.d/50-server.cnf`:

```bash
sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf
```

Increase buffer pool (for 2GB+ RAM servers):

```ini
innodb_buffer_pool_size = 1G
innodb_log_file_size = 256M
max_connections = 200
```

Restart MariaDB:

```bash
sudo systemctl restart mariadb
```

## Next Steps

Once MariaDB is set up:

1. Run the deploy script: `sudo ./scripts/deploy.sh`
2. The script will auto-detect MariaDB and run migrations
3. Your Kodakclout server will be live at `https://cloutscape.org`

---

**Questions?** Check the logs:

```bash
sudo journalctl -u mariadb -f
```
