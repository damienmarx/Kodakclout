import { mysqlTable, varchar, timestamp, text, boolean, int } from "drizzle-orm/mysql-core";

export const users = mysqlTable("users", {
  id: int("id").primaryKey().autoincrement(),
  email: varchar("email", { length: 255 }).notNull().unique(),
  name: varchar("name", { length: 255 }).notNull(),
  avatar: text("avatar"),
  password: text("password"),
  googleId: varchar("google_id", { length: 255 }).unique(),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().onUpdateNow().notNull(),
  balance: int("balance").default(0).notNull(),
});

export const sessions = mysqlTable("sessions", {
  id: varchar("id", { length: 255 }).primaryKey(),
  userId: int("user_id").notNull(),
  expiresAt: timestamp("expires_at").notNull(),
});

export const games = mysqlTable("games", {
  id: varchar("id", { length: 255 }).primaryKey(),
  slug: varchar("slug", { length: 255 }).notNull().unique(),
  title: varchar("title", { length: 255 }).notNull(),
  provider: varchar("provider", { length: 50 }).notNull(),
  category: varchar("category", { length: 50 }).notNull(),
  thumbnail: text("thumbnail").notNull(),
  description: text("description"),
  isActive: boolean("is_active").default(true).notNull(),
  isNew: boolean("is_new").default(false).notNull(),
  isHot: boolean("is_hot").default(false).notNull(),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

export const transactions = mysqlTable("transactions", {
  id: int("id").primaryKey().autoincrement(),
  userId: int("user_id").notNull(),
  amount: int("amount").notNull(),
  type: varchar("type", { length: 50 }).notNull(), // deposit, withdraw, bet, win
  reference: varchar("reference", { length: 255 }), // game slug or tx hash
  createdAt: timestamp("created_at").defaultNow().notNull(),
});