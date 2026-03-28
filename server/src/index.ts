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

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = process.env.PORT || 8080;

const IS_PROD = process.env.NODE_ENV === "production";

// ─── CORS ─────────────────────────────────────────────────────────────────────
// Allow the production domain, www variant, and localhost for dev.
const allowedOrigins = [
  process.env.CLIENT_URL || "https://cloutscape.org",
  "https://www.cloutscape.org",
  "http://localhost:5173",
  "http://localhost:3000",
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

// ─── Health Check ────────────────────────────────────────────────────────────
app.get(`${API_PREFIX}/health`, (_req, res) => {
  res.json({ status: "ok", ts: Date.now() });
});

// ─── tRPC ─────────────────────────────────────────────────────────────────────
app.use(
  TRPC_PREFIX,
  trpcExpress.createExpressMiddleware({
    router: appRouter,
    createContext,
  })
);

// OAuth Routes (Mock for now)
app.get(`${API_PREFIX}/oauth/google`, (req, res) => {
  // Redirect to Google OAuth
  res.redirect(`https://accounts.google.com/o/oauth2/v2/auth?client_id=${process.env.GOOGLE_CLIENT_ID}&redirect_uri=${process.env.CLIENT_URL}/api/oauth/google/callback&response_type=code&scope=email%20profile`);
});

app.get(`${API_PREFIX}/oauth/google/callback`, async (req, res) => {
  // Handle Google OAuth callback, create session, etc.
  // This would typically use the google-auth-library
  res.redirect(`${process.env.CLIENT_URL}/home`);
});

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
// __dirname in production = <project-root>/server/dist
// client/dist             = <project-root>/client/dist
if (IS_PROD) {
  const clientDist = path.resolve(__dirname, "../../client/dist");

  // Serve static assets (JS, CSS, images, etc.)
  app.use(express.static(clientDist));

  // SPA catch-all: every non-API path returns index.html so React Router works
  app.get("*", (req, res) => {
    if (req.path.startsWith(API_PREFIX)) {
      res.status(404).json({ error: "API route not found" });
    } else {
      res.sendFile(path.join(clientDist, "index.html"));
    }
  });
}

app.listen(PORT, () => {
  console.log(`Kodakclout server running on port ${PORT}`);
  console.log(`Environment: ${IS_PROD ? "production" : "development"}`);
  console.log(`tRPC endpoint: ${TRPC_PREFIX}`);
  if (IS_PROD) {
    console.log(`Frontend served from: ${path.resolve(__dirname, "../../client/dist")}`);
  }
});
