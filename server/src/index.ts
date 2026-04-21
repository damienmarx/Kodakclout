import express from "express";
import * as trpcExpress from "@trpc/server/adapters/express";
import cors from "cors";
import cookieParser from "cookie-parser";
import path from "path";
import { fileURLToPath } from "url";
import dotenv from "dotenv";
import { appRouter } from "./trpc/router.js";
import { createContext } from "./trpc/trpc.js";
import { API_PREFIX, TRPC_PREFIX } from "@kodakclout/shared";
import { checkDbHealth } from "./db/index.js";
import { ClutchProvider } from "./providers/clutch.js";

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = process.env.PORT || 8080;
const IS_PROD = process.env.NODE_ENV === "production";
const MAINTENANCE_MODE = process.env.MAINTENANCE_MODE === "true";

// ─── CORS ─────────────────────────────────────────────────────────────────────
const allowedOrigins = [
  process.env.CLIENT_URL || "http://localhost:3000",
  "http://localhost:5173",
  "http://localhost:8080",
];

app.use(
  cors({
    origin: (origin, callback) => {
      if (!origin || allowedOrigins.includes(origin)) {
        callback(null, true);
      } else {
        callback(new Error(`CORS: origin ${origin} not allowed`));
      }
    },
    credentials: true,
  })
);

app.use(express.json());
app.use(cookieParser());

// ─── Maintenance Middleware ──────────────────────────────────────────────────
app.use((req, res, next) => {
  if (MAINTENANCE_MODE && !req.path.startsWith(`${API_PREFIX}/health`)) {
    return res.status(503).json({ 
      error: "Service under maintenance", 
      message: "We are currently performing scheduled updates. Please check back soon." 
    });
  }
  next();
});

// ─── Enhanced Health Check ───────────────────────────────────────────────────
app.get(`${API_PREFIX}/health`, async (_req, res) => {
  const dbHealth = await checkDbHealth();
  const clutch = ClutchProvider.getInstance();
  let clutchHealth = "unknown";
  
  try {
    const games = await clutch.getGames();
    clutchHealth = games.length > 0 ? "healthy" : "no_games";
  } catch {
    clutchHealth = "unreachable";
  }

  const isHealthy = dbHealth.status === "connected" && !MAINTENANCE_MODE;
  
  res.status(isHealthy ? 200 : 503).json({
    status: isHealthy ? "ok" : "degraded",
    maintenance: MAINTENANCE_MODE,
    database: dbHealth,
    clutch: clutchHealth,
    ts: Date.now(),
    version: process.env.npm_package_version || "1.0.0"
  });
});

// ─── tRPC ─────────────────────────────────────────────────────────────────────
app.use(
  TRPC_PREFIX,
  trpcExpress.createExpressMiddleware({
    router: appRouter,
    createContext,
  })
);

// ─── REST Game Route (non-tRPC clients) ──────────────────────────────────────
app.get(`${API_PREFIX}/games`, async (req, res) => {
  const caller = appRouter.createCaller({ req, res, user: null });
  try {
    const result = await caller.getGames({ page: 1, pageSize: 24 });
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: "Failed to fetch games" });
  }
});

// ─── Production: Serve Frontend ──────────────────────────────────────────────
if (IS_PROD) {
  const clientDist = path.resolve(__dirname, "../../client/dist");
  app.use(express.static(clientDist));
  app.get("*", (req, res) => {
    if (req.path.startsWith(API_PREFIX)) {
      res.status(404).json({ error: "API route not found" });
    } else {
      res.sendFile(path.join(clientDist, "index.html"));
    }
  });
}

const server = app.listen(PORT, () => {
  if (process.env.NODE_ENV !== "production") {
    console.log(`Kodakclout server running on port ${PORT}`);
    console.log(`Environment: ${IS_PROD ? "production" : "development"}`);
    console.log(`tRPC endpoint: ${TRPC_PREFIX}`);
  }
});

// Graceful Shutdown
process.on("SIGTERM", () => {
  server.close(() => {
    process.exit(0);
  });
});
