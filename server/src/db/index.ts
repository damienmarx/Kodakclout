import { drizzle } from "drizzle-orm/mysql2";
import mysql from "mysql2/promise";
import * as schema from "./schema.js";
import dotenv from "dotenv";

dotenv.config();

if (!process.env.DATABASE_URL) {
  throw new Error("DATABASE_URL is not defined in the environment variables");
}

/**
 * Enhanced Database Connection with Error Handling and Callbacks
 */
const createConnection = () => {
  try {
    const pool = mysql.createPool({
      uri: process.env.DATABASE_URL,
      waitForConnections: true,
      connectionLimit: 10,
      queueLimit: 0,
      enableKeepAlive: true,
      keepAliveInitialDelay: 0,
    });

    // Connection lifecycle callbacks
    pool.on("acquire", (connection) => {
      console.log(`[DB] Connection ${connection.threadId} acquired`);
    });

    pool.on("enqueue", () => {
      console.warn("[DB] Waiting for available connection slot");
    });

    pool.on("release", (connection) => {
      console.log(`[DB] Connection ${connection.threadId} released`);
    });

    pool.on("connection", (connection) => {
      console.log("[DB] New connection established in pool");
    });

    return pool;
  } catch (error) {
    console.error("[DB] Failed to create connection pool:", error);
    process.exit(1);
  }
};

const pool = createConnection();

// Initialize Drizzle with the enhanced pool
export const db = drizzle(pool, { 
  schema, 
  mode: "default",
  // Log queries in development for better debugging
  logger: process.env.NODE_ENV === "development"
});

/**
 * Health check utility for the database
 */
export const checkDbHealth = async () => {
  try {
    await pool.query("SELECT 1");
    return { status: "connected", timestamp: new Date().toISOString() };
  } catch (error) {
    console.error("[DB] Health check failed:", error);
    return { status: "disconnected", error: error instanceof Error ? error.message : String(error) };
  }
};
