import { router, protectedProcedure } from "./trpc.js";
import { z } from "zod";
import { TRPCError } from "@trpc/server";
import { db } from "../db/index.js";
import { users, games } from "../db/schema.js";
import { eq, sql } from "drizzle-orm";

// Admin middleware to check if user is admin
const adminProcedure = protectedProcedure.use(({ ctx, next }) => {
  // For now, we'll check if user ID is 1 (first admin user)
  // In production, add an isAdmin column to users table
  const ADMIN_USER_IDS = [1]; // Add admin user IDs here

  if (!ADMIN_USER_IDS.includes(ctx.user.userId)) {
    throw new TRPCError({
      code: "FORBIDDEN",
      message: "You do not have admin privileges",
    });
  }

  return next({
    ctx: {
      ...ctx,
      user: ctx.user,
    },
  });
});

export const adminRouter = router({
  // User Management
  listUsers: adminProcedure
    .input(z.object({
      page: z.number().min(1).default(1),
      pageSize: z.number().min(1).max(100).default(20),
    }))
    .query(async ({ input }) => {
      const offset = (input.page - 1) * input.pageSize;

      const allUsers = await db.select().from(users).limit(input.pageSize).offset(offset);
      const [{ count }] = await db.select({ count: sql<number>`count(*)` }).from(users);

      return {
        users: allUsers.map(u => ({
          id: u.id,
          email: u.email,
          name: u.name,
          avatar: u.avatar,
          balance: u.balance,
          createdAt: u.createdAt,
          updatedAt: u.updatedAt,
        })),
        total: count,
        page: input.page,
        pageSize: input.pageSize,
      };
    }),

  getUserById: adminProcedure
    .input(z.object({ userId: z.number() }))
    .query(async ({ input }) => {
      const [user] = await db.select().from(users).where(eq(users.id, input.userId));

      if (!user) {
        throw new TRPCError({
          code: "NOT_FOUND",
          message: "User not found",
        });
      }

      return {
        id: user.id,
        email: user.email,
        name: user.name,
        avatar: user.avatar,
        balance: user.balance,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      };
    }),

  updateUserBalance: adminProcedure
    .input(z.object({
      userId: z.number(),
      balance: z.number().min(0),
    }))
    .mutation(async ({ input }) => {
      const [user] = await db.select().from(users).where(eq(users.id, input.userId));

      if (!user) {
        throw new TRPCError({
          code: "NOT_FOUND",
          message: "User not found",
        });
      }

      await db.update(users)
        .set({ balance: input.balance })
        .where(eq(users.id, input.userId));

      return { success: true, balance: input.balance };
    }),

  // Game Management
  listGames: adminProcedure
    .input(z.object({
      page: z.number().min(1).default(1),
      pageSize: z.number().min(1).max(100).default(20),
    }))
    .query(async ({ input }) => {
      const offset = (input.page - 1) * input.pageSize;

      const allGames = await db.select().from(games).limit(input.pageSize).offset(offset);
      const [{ count }] = await db.select({ count: sql<number>`count(*)` }).from(games);

      return {
        games: allGames,
        total: count,
        page: input.page,
        pageSize: input.pageSize,
      };
    }),

  updateGame: adminProcedure
    .input(z.object({
      gameId: z.string(),
      title: z.string().optional(),
      description: z.string().optional(),
      isActive: z.boolean().optional(),
      isNew: z.boolean().optional(),
      isHot: z.boolean().optional(),
    }))
    .mutation(async ({ input }) => {
      const [game] = await db.select().from(games).where(eq(games.id, input.gameId));

      if (!game) {
        throw new TRPCError({
          code: "NOT_FOUND",
          message: "Game not found",
        });
      }

      const updates: Partial<typeof games.$inferSelect> = {};
      if (input.title !== undefined) updates.title = input.title;
      if (input.description !== undefined) updates.description = input.description;
      if (input.isActive !== undefined) updates.isActive = input.isActive;
      if (input.isNew !== undefined) updates.isNew = input.isNew;
      if (input.isHot !== undefined) updates.isHot = input.isHot;

      await db.update(games)
        .set(updates)
        .where(eq(games.id, input.gameId));

      return { success: true, game: { ...game, ...updates } };
    }),

  toggleGameStatus: adminProcedure
    .input(z.object({
      gameId: z.string(),
      isActive: z.boolean(),
    }))
    .mutation(async ({ input }) => {
      const [game] = await db.select().from(games).where(eq(games.id, input.gameId));

      if (!game) {
        throw new TRPCError({
          code: "NOT_FOUND",
          message: "Game not found",
        });
      }

      await db.update(games)
        .set({ isActive: input.isActive })
        .where(eq(games.id, input.gameId));

      return { success: true, isActive: input.isActive };
    }),

  // Analytics
  getStats: adminProcedure.query(async () => {
    const [{ count: userCount }] = await db.select({ count: sql<number>`count(*)` }).from(users);
    const [{ count: gameCount }] = await db.select({ count: sql<number>`count(*)` }).from(games);

    return {
      totalUsers: userCount,
      totalGames: gameCount,
      timestamp: new Date().toISOString(),
    };
  }),
});
