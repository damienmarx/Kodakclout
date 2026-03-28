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

// Middleware
app.use(cors({
  origin: process.env.CLIENT_URL || "http://localhost:5173",
  credentials: true,
}));
app.use(express.json());
app.use(cookieParser());

// tRPC
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

// Game Routes
app.get(`${API_PREFIX}/games`, async (req, res) => {
  // Direct API for non-tRPC clients
  const { appRouter } = await import("./trpc/router.js");
  const caller = appRouter.createCaller({ req, res, user: null });
  try {
    const result = await caller.getGames({ page: 1, pageSize: 24 });
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: "Failed to fetch games" });
  }
});

// Production: Serve frontend
if (process.env.NODE_ENV === "production") {
  const clientDist = path.join(__dirname, "../../client/dist");
  app.use(express.static(clientDist));
  app.get("*", (req, res) => {
    if (!req.path.startsWith(API_PREFIX)) {
      res.sendFile(path.join(clientDist, "index.html"));
    }
  });
}

app.listen(PORT, () => {
  console.log(`Kodakclout server running on port ${PORT}`);
  console.log(`tRPC endpoint: ${TRPC_PREFIX}`);
});
