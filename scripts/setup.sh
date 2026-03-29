#!/bin/bash

# Kodakclout Setup Script
# Developed for damienmarx
# This script automates the installation of dependencies, database setup, and environment configuration.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Starting Kodakclout Setup...${NC}"

# 1. Check for Node.js and pnpm
echo -e "${YELLOW}🔍 Checking dependencies...${NC}"
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js is not installed. Please install Node.js >= 18.0.0${NC}"
    exit 1
fi

if ! command -v pnpm &> /dev/null; then
    echo -e "${YELLOW}📦 pnpm not found. Installing pnpm...${NC}"
    sudo npm install -g pnpm
fi

# 2. Install Dependencies
echo -e "${YELLOW}📦 Installing project dependencies...${NC}"
pnpm install

# 3. Database Setup (MariaDB)
echo -e "${YELLOW}🗄️ Setting up MariaDB...${NC}"
if ! command -v mariadb &> /dev/null; then
    echo -e "${YELLOW}📥 Installing MariaDB Server...${NC}"
    sudo apt-get update
    sudo apt-get install -y mariadb-server mariadb-client
    sudo systemctl start mariadb
    sudo systemctl enable mariadb
fi

# Create Database and User if they don't exist
DB_NAME="kodakclout"
DB_USER="clout_user"
DB_PASS="clout_pass"

echo -e "${YELLOW}🔑 Configuring database user and permissions...${NC}"
sudo mariadb -u root <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# 4. Environment Configuration
echo -e "${YELLOW}📝 Configuring environment variables...${NC}"
if [ ! -f server/.env ]; then
    echo -e "${YELLOW}📄 Creating server/.env from template...${NC}"
    if [ -f server/.env.example ]; then
        cp server/.env.example server/.env
    else
        cat <<EOF > server/.env
PORT=3001
DATABASE_URL=mysql://$DB_USER:$DB_PASS@127.0.0.1:3306/$DB_NAME
NODE_ENV=development
EOF
    fi
    echo -e "${GREEN}✅ Created server/.env. Please review it later.${NC}"
else
    echo -e "${GREEN}✅ server/.env already exists.${NC}"
fi

# 5. Run Migrations
echo -e "${YELLOW}🏗️ Running database migrations...${NC}"
cd server
pnpm migrate
cd ..

echo -e "${GREEN}✨ Kodakclout setup complete!${NC}"
echo -e "${YELLOW}To start the development server, run:${NC}"
echo -e "${GREEN}pnpm dev${NC}"
