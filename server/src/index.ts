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
import { OAuth2Client } from "google-auth-library";

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

// ─── OAuth Routes ──────────────────────────────────────────────────────────────
// Google OAuth initiation
app.get(`${API_PREFIX}/oauth/google`, (req, res) => {
  const clientId = process.env.GOOGLE_CLIENT_ID;
  const redirectUri = `${process.env.SERVER_URL || 'http://localhost:8080'}${API_PREFIX}/oauth/google/callback`;
  const scope = "openid email profile";
  const responseType = "code";

  const authUrl = `https://accounts.google.com/o/oauth2/v2/auth?client_id=${clientId}&redirect_uri=${encodeURIComponent(redirectUri)}&response_type=${responseType}&scope=${encodeURIComponent(scope)}`;
  
  res.redirect(authUrl);
});

// Google OAuth callback handler
app.get(`${API_PREFIX}/oauth/google/callback`, async (req, res) => {
  const { code, error } = req.query;

  if (error) {
    return res.redirect(`${process.env.CLIENT_URL || 'http://localhost:3000'}/login?error=${error}`);
  }

  if (!code || typeof code !== 'string') {
    return res.redirect(`${process.env.CLIENT_URL || 'http://localhost:3000'}/login?error=missing_code`);
  }

  try {
    // Call the tRPC procedure to handle OAuth callback
    const caller = appRouter.createCaller({ req, res, user: null });
    const result = await caller.auth.googleOAuthCallback({ code });

    // Redirect to home page on success
    res.redirect(`${process.env.CLIENT_URL || 'http://localhost:3000'}/home`);
  } catch (error) {
    console.error("OAuth callback error:", error);
    const errorMessage = error instanceof Error ? error.message : "OAuth failed";
    res.redirect(`${process.env.CLIENT_URL || 'http://localhost:3000'}/login?error=${encodeURIComponent(errorMessage)}`);
  }
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
