import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import path from "path";

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
      "@shared": path.resolve(__dirname, "../shared/src"),
      // Required for the trpc.ts import: `import type { AppRouter } from "@server/trpc/router"`
      "@server": path.resolve(__dirname, "../server/src"),
      // Resolve the workspace package directly from source so Vite never
      // needs a pre-built shared/dist (which is git-ignored).
      "@kodakclout/shared": path.resolve(__dirname, "../shared/src/index.ts"),
    },
  },
  build: {
    // Explicit output directory (default is dist, but being explicit avoids confusion)
    outDir: "dist",
    // No source maps in production builds
    sourcemap: false,
    // Raise the chunk warning limit a bit for a casino with many game assets
    chunkSizeWarningLimit: 1000,
  },
  server: {
    port: 5173,
    proxy: {
      // Proxy all /api calls to the Express backend during development
      "/api": {
        target: "http://localhost:8080",
        changeOrigin: true,
        secure: false,
      },
    },
  },
});
