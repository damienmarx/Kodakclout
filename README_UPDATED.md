# Kodakclout - Premium Gaming Platform

A modern, full-stack gaming platform built with Node.js, React, and tRPC. Kodakclout provides a seamless experience for managing games, user authentication, and in-game transactions.

## 🚀 Features

### Core Features
- **Real-time Game Integration**: Seamless integration with Clutch Go gaming engine
- **User Authentication**: Secure JWT-based authentication with Google OAuth support
- **Wallet & Credits System**: In-game currency management with deposit/withdraw functionality
- **Game Lobby**: Dynamic game discovery and launching with filtering and search
- **Responsive Design**: Mobile-first UI built with React and TailwindCSS
- **Type-Safe API**: Full-stack type safety with tRPC and TypeScript

### Advanced Features
- **Admin Panel**: User and game management with analytics
- **Database Migrations**: Automated schema management with Drizzle ORM
- **Session Management**: Persistent login with secure cookie-based sessions
- **Balance Display**: Real-time user balance tracking across all pages
- **Game Metadata**: Comprehensive game information including provider, category, and status

## 📋 Tech Stack

### Frontend
- **React 18** - UI library
- **TypeScript** - Type safety
- **Vite** - Build tool and dev server
- **TailwindCSS** - Utility-first CSS framework
- **React Router** - Client-side routing
- **tRPC Client** - Type-safe API client
- **Lucide React** - Icon library

### Backend
- **Node.js 22** - JavaScript runtime
- **Express** - Web framework
- **tRPC** - Type-safe RPC framework
- **TypeScript** - Type safety
- **Drizzle ORM** - Database ORM
- **MySQL 8** - Database
- **JWT** - Authentication tokens
- **Google Auth Library** - OAuth integration
- **bcrypt** - Password hashing

### DevOps
- **pnpm** - Package manager
- **PM2** - Process manager
- **Nginx** - Reverse proxy
- **Docker** - Containerization (optional)
- **Let's Encrypt** - SSL/TLS certificates

## 🛠️ Installation

### Prerequisites
- Node.js 18+ (tested with v22.13.0)
- pnpm 8+
- MySQL 8.0+
- Debian/Ubuntu OS (for automated deployment)

### Quick Start (Automated)

The easiest way to deploy Kodakclout:

```bash
# Clone the repository
git clone https://github.com/damienmarx/Kodakclout.git
cd Kodakclout

# Run the universal deployment script
sudo bash scripts/deploy-universal.sh
```

This script will:
- Install all system dependencies
- Set up Node.js and pnpm
- Create application user and directories
- Configure MySQL database
- Build the application
- Set up PM2 process management
- Configure Nginx reverse proxy
- Optionally set up SSL/TLS

See [QUICK_START.md](./QUICK_START.md) for detailed post-deployment configuration.

### Manual Installation

For non-Debian systems or custom setups:

```bash
# Install dependencies
pnpm install

# Configure environment
cp .env.example .env
# Edit .env with your configuration

# Build all packages
pnpm build

# Run database migrations
pnpm --filter @kodakclout/server run migrate

# Seed initial data
pnpm --filter @kodakclout/server run seed

# Start development server
pnpm --filter @kodakclout/server run dev

# In another terminal, start the client
pnpm --filter @kodakclout/client run dev
```

## 📁 Project Structure

```
Kodakclout/
├── client/                 # React frontend application
│   ├── src/
│   │   ├── pages/         # Page components
│   │   ├── context/       # React context (auth)
│   │   ├── lib/           # Utilities and tRPC client
│   │   └── index.css      # Global styles
│   └── package.json
├── server/                 # Node.js backend
│   ├── src/
│   │   ├── db/            # Database schema and utilities
│   │   ├── trpc/          # tRPC routers (auth, admin, etc.)
│   │   ├── providers/     # External service integrations
│   │   ├── scripts/       # Utility scripts (seeding, etc.)
│   │   └── index.ts       # Express server entry point
│   └── package.json
├── shared/                 # Shared types and schemas
│   ├── src/
│   │   ├── types/         # TypeScript interfaces
│   │   ├── schemas/       # Zod validation schemas
│   │   └── constants.ts   # Shared constants
│   └── package.json
├── scripts/               # Deployment and utility scripts
│   ├── deploy-universal.sh    # Complete deployment script
│   ├── setup.sh               # Basic setup
│   └── seed-games.ts          # Game data seeding
├── .env.example           # Environment template
├── DEPLOYMENT.md          # Detailed deployment guide
├── QUICK_START.md         # Quick start guide
└── README.md              # This file
```

## 🔧 Configuration

### Environment Variables

Create a `.env` file based on `.env.example`:

```env
# Database
DATABASE_URL=mysql://user:password@localhost:3306/kodakclout

# Server
PORT=8080
NODE_ENV=production
SERVER_URL=https://cloutscape.org
CLIENT_URL=https://cloutscape.org

# JWT
JWT_SECRET=your-secure-random-key
PASSWORD_SALT_ROUNDS=12

# Google OAuth
GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-client-secret

# Clutch Engine
CLUTCH_API_URL=https://api.clutch.io
CLUTCH_API_KEY=your-api-key
```

## 🚀 Deployment

### One-Command Deployment (Debian/Ubuntu)

```bash
sudo bash scripts/deploy-universal.sh
```

### Manual Deployment

See [DEPLOYMENT.md](./DEPLOYMENT.md) for comprehensive deployment instructions including:
- System setup and configuration
- Database setup and migrations
- Building for production
- Nginx reverse proxy configuration
- SSL/TLS certificate setup
- PM2 process management
- Monitoring and troubleshooting

### Docker Deployment

```bash
# Build Docker image
docker build -t kodakclout:latest .

# Run container
docker run -p 8080:8080 --env-file .env kodakclout:latest
```

## 📊 Database Schema

### Users Table
```sql
CREATE TABLE users (
  id INT PRIMARY KEY AUTO_INCREMENT,
  email VARCHAR(255) UNIQUE NOT NULL,
  name VARCHAR(255) NOT NULL,
  avatar TEXT,
  password TEXT,
  google_id VARCHAR(255) UNIQUE,
  balance INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

### Games Table
```sql
CREATE TABLE games (
  id VARCHAR(255) PRIMARY KEY,
  slug VARCHAR(255) UNIQUE NOT NULL,
  title VARCHAR(255) NOT NULL,
  provider VARCHAR(50) NOT NULL,
  category VARCHAR(50) NOT NULL,
  thumbnail TEXT NOT NULL,
  description TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  is_new BOOLEAN DEFAULT FALSE,
  is_hot BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Sessions Table
```sql
CREATE TABLE sessions (
  id VARCHAR(255) PRIMARY KEY,
  user_id INT,
  expires_at TIMESTAMP NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id)
);
```

## 🔐 Security Features

- **Password Hashing**: bcrypt with 12 salt rounds
- **JWT Authentication**: Secure token-based authentication
- **HTTPS/TLS**: SSL/TLS encryption for all traffic
- **CORS Protection**: Configurable CORS origins
- **Input Validation**: Zod schema validation on all inputs
- **SQL Injection Prevention**: Parameterized queries with Drizzle ORM
- **XSS Protection**: React's built-in XSS protection
- **Secure Cookies**: HttpOnly, Secure, SameSite flags

## 📱 API Endpoints

### Authentication
- `POST /api/trpc/auth.register` - Register new user
- `POST /api/trpc/auth.login` - Login with email/password
- `POST /api/trpc/auth.logout` - Logout current user
- `POST /api/trpc/auth.googleOAuthCallback` - Handle Google OAuth

### Games
- `GET /api/trpc/getGames` - List games with filtering
- `POST /api/trpc/launchGame` - Launch a game session

### User
- `GET /api/trpc/me` - Get current user info and balance
- `POST /api/trpc/deposit` - Deposit funds to account
- `POST /api/trpc/withdraw` - Withdraw funds from account

### Admin (Protected)
- `GET /api/trpc/admin.listUsers` - List all users
- `GET /api/trpc/admin.getUserById` - Get user details
- `POST /api/trpc/admin.updateUserBalance` - Update user balance
- `GET /api/trpc/admin.listGames` - List all games
- `POST /api/trpc/admin.updateGame` - Update game metadata
- `POST /api/trpc/admin.toggleGameStatus` - Enable/disable game
- `GET /api/trpc/admin.getStats` - Get platform statistics

### Health
- `GET /api/health` - Health check endpoint

## 🧪 Testing

### Run Type Checking
```bash
pnpm -r exec tsc --noEmit
```

### Build All Packages
```bash
pnpm build
```

### Run Development Servers
```bash
# Terminal 1: Backend
pnpm --filter @kodakclout/server run dev

# Terminal 2: Frontend
pnpm --filter @kodakclout/client run dev
```

## 📚 Documentation

- [QUICK_START.md](./QUICK_START.md) - Quick start and post-deployment guide
- [DEPLOYMENT.md](./DEPLOYMENT.md) - Comprehensive deployment guide
- [TODO.md](./TODO.md) - Development roadmap and future features

## 🐛 Troubleshooting

### Application won't start
```bash
# Check PM2 logs
pm2 logs kodakclout-server

# Check if port is in use
sudo lsof -i :8080
```

### Database connection error
```bash
# Test connection
mysql -u kodakclout -p -h localhost kodakclout

# Check service status
sudo systemctl status mysql
```

### Build errors
```bash
# Clear cache and reinstall
rm -rf node_modules pnpm-lock.yaml
pnpm install
pnpm build
```

See [QUICK_START.md](./QUICK_START.md) for more troubleshooting tips.

## 📈 Performance

- **Frontend**: Optimized with Vite and TailwindCSS
- **Backend**: Efficient database queries with Drizzle ORM
- **Caching**: Browser caching for static assets
- **Compression**: Gzip compression for responses
- **Connection Pooling**: MySQL connection pool management

## 🔄 Continuous Integration

The repository includes deployment scripts for automated setup. For CI/CD pipelines:

1. Build all packages: `pnpm build`
2. Run type checking: `pnpm -r exec tsc --noEmit`
3. Deploy: `sudo bash scripts/deploy-universal.sh`

## 📄 License

This project is proprietary software. All rights reserved.

## 👥 Contributing

For contributions, please contact the development team or submit issues on GitHub.

## 📞 Support

- **Issues**: Report on GitHub
- **Documentation**: See QUICK_START.md and DEPLOYMENT.md
- **Email**: Contact the development team

## 🎯 Roadmap

See [TODO.md](./TODO.md) for upcoming features and improvements:
- Leaderboards & Achievements
- Promotions & Bonuses
- Multi-Currency Support
- Real-time Chat
- Advanced Analytics
- Mobile App

## 🙏 Acknowledgments

Built with modern web technologies and best practices for security, performance, and user experience.

---

**Kodakclout** - Premium Gaming Platform for Elite Players
