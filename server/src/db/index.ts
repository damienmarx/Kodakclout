import { drizzle } from "drizzle-orm/mysql2";
import mysql from "mysql2/promise";
import * as schema from "./schema.js";
import dotenv from "dotenv";

dotenv.config();

if (!process.env.DATABASE_URL) {
  throw new Error("DATABASE_URL is not defined in the environment variables");
}

/**
 * Hardened Database Connection Pool
 */
export const createConnection = () => {
  try {
    const pool = mysql.createPool({
      uri: process.env.DATABASE_URL,
      waitForConnections: true,
      connectionLimit: 20, // Increased for production
      queueLimit: 0,
      enableKeepAlive: true,
      keepAliveInitialDelay: 10000,
      connectTimeout: 10000, // 10s timeout
    });

    // Error handling for the pool
    (pool as any).on("error", (err: Error) => {
      if (process.env.NODE_ENV !== "production") {
        console.error("[DB] Unexpected pool error:", err);
      }
    });

    return pool;
  } catch (error) {
    if (process.env.NODE_ENV !== "production") {
      console.error("[DB] Failed to create connection pool:", error);
    }
    process.exit(1);
  }
};

const pool = createConnection();

// Initialize Drizzle with the hardened pool
export const db = drizzle(pool, { 
  schema, 
  mode: "default",
  // No logging in production for performance and security
  logger: process.env.NODE_ENV === "development"
});

/**
 * Health check utility for the database
 */
export const checkDbHealth = async () => {
  try {
    const connection = await pool.getConnection();
    await connection.query("SELECT 1");
    connection.release();
    return { status: "connected", timestamp: new Date().toISOString() };
  } catch (error) {
    return { 
      status: "disconnected", 
      error: error instanceof Error ? error.message : "Unknown database error" 
    };
  }
};
