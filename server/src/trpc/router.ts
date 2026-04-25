import { router, publicProcedure, protectedProcedure } from "./trpc.js";
import { GamesQuery, Session } from "@kodakclout/shared";
import { GamesQuerySchema, GamesListResponseSchema, GameLaunchResponseSchema } from "@kodakclout/shared";

import { InternalProvider } from "../providers/internal.js";
import { authRouter } from "./auth.js";
import { adminRouter } from "./admin.js";
import { z } from "zod";
import { db, createConnection } from "../db/index.js";
import jwt from "jsonwebtoken";
import axios from "axios";
import { users, transactions } from "../db/schema.js";
import { eq, sql } from "drizzle-orm";
import mysql from "mysql2/promise";


const internal = InternalProvider.getInstance();

// Get a raw mysql2 connection pool
const rawPool = createConnection();

export const appRouter = router({
  auth: authRouter,
  admin: adminRouter,
  getGames: publicProcedure
    .input(GamesQuerySchema)
    .output(GamesListResponseSchema)
    .query(async ({ input }: { input: GamesQuery }) => {
      const { page, pageSize, category, search, provider } = input;

      let whereClauses: string[] = ['1=1'];
      const params: (string | number)[] = [];

      if (category) {
        whereClauses.push(`category = ?`);
        params.push(category);
      }
      if (provider) {
        whereClauses.push(`provider = ?`);
        params.push(provider);
      }
      if (search) {
        whereClauses.push(`(title LIKE ? OR slug LIKE ?)`);
        params.push(`%${search}%`);
        params.push(`%${search}%`);
      }

      const whereSql = whereClauses.join(" AND ");

      const [rows] = await rawPool.execute<mysql.RowDataPacket[]>(`
        SELECT
          id,
          slug,
          title,
          provider,
          category,
          thumbnail,
          description,
          is_active as isActive,
          is_new as isNew,
          is_hot as isHot,
          clutch_alias as clutchAlias
        FROM games
        WHERE ${whereSql}
        LIMIT ? OFFSET ?
      `, [...params, pageSize, (page - 1) * pageSize]);

      const [totalRows] = await rawPool.execute<mysql.RowDataPacket[]>(`
        SELECT COUNT(*) as count
        FROM games
        WHERE ${whereSql}
      `, params);
      const total = (totalRows[0] as { count: number }).count;

      const games = rows.map((row: any) => ({
        id: row.id,
        slug: row.slug,
        title: row.title,
        provider: (row.provider === 'clutch' || row.provider === 'internal') ? row.provider : 'internal', // Default to internal if unknown'
        category: row.category || 'slots',
        thumbnail: row.thumbnail,
        description: row.description,
        isNew: !!row.isNew,
        isHot: !!row.isHot,
        isActive: !!row.isActive,
        clutchAlias: row.clutchAlias,
      }));

      return {
        games: games,
        total,
        page,
        pageSize
      };
    }),

  launchGame: publicProcedure
    .input(z.object({ slug: z.string() }))
    .output(GameLaunchResponseSchema)
    .mutation(async ({ input, ctx }: { input: { slug: string }, ctx: { user?: Session | null } }) => {
      const internalGames = await internal.getGames();
      const isInternal = internalGames.some(g => g.slug === input.slug);
      
      if (isInternal) {
        return await internal.getLaunchUrl(input.slug, ctx.user?.userId?.toString() || '1'); 
      }
      
      const [gameRows] = await rawPool.execute<mysql.RowDataPacket[]>(`
        SELECT clutch_alias FROM games WHERE slug = ?
      `, [input.slug]);

      if (gameRows.length === 0 || !gameRows[0].clutch_alias) {
        throw new Error(`Clutch game with slug ${input.slug} not found or missing clutch_alias`);
      }
      const clutchAlias = gameRows[0].clutch_alias;

      const JWT_SECRET = process.env.CLUTCH_API_KEY || "local-clutch-key";
      const now = Math.floor(Date.now() / 1000);
      const exp = now + 300;
      const token = jwt.sign(
        { uid: ctx.user?.userId || 1, cid: 1, iss: 'slotopol', exp: exp },
        JWT_SECRET
      );

      const clutchResponse = await axios.post(
        `${process.env.CLUTCH_API_URL || 'http://localhost:8081'}/game/new`,
        { cid: 1, uid: ctx.user?.userId || 1, alias: clutchAlias },
        { headers: { 'Authorization': `Bearer ${token}` } }
      );
      const { gid } = clutchResponse.data;

      return {
        url: `https://clutch.cloutscape.org/?gid=${gid}&cid=1&uid=${ctx.user?.userId || 1}`,
        token: token,
        expiresAt: new Date(exp * 1000).toISOString(),
      };
    }),

  me: publicProcedure.query(async ({ ctx }: { ctx: { user: Session | null } }) => {
    if (!ctx.user) return null;
    
    const [user] = await db.select().from(users).where(eq(users.id, ctx.user.userId));
    if (!user) return null;

    return {
      ...ctx.user,
      balance: user.balance
    };
  }),

  deposit: protectedProcedure
    .input(z.object({ amount: z.number().positive() }))
    .mutation(async ({ input, ctx }) => {
      return await db.transaction(async (tx) => {
        await tx.update(users)
          .set({ balance: sql`${users.balance} + ${input.amount}` })
          .where(eq(users.id, ctx.user.userId));
        
        await tx.insert(transactions).values({
          userId: ctx.user.userId,
          amount: input.amount,
          type: "deposit",
          reference: "manual_deposit"
        });
        
        const [user] = await tx.select().from(users).where(eq(users.id, ctx.user.userId));
        if (!user) throw new Error("User not found during deposit");
        return { balance: user.balance };
      });
    }),

  withdraw: protectedProcedure
    .input(z.object({ amount: z.number().positive() }))
    .mutation(async ({ input, ctx }) => {
      return await db.transaction(async (tx) => {
        const [user] = await tx.select().from(users).where(eq(users.id, ctx.user.userId));
        if (!user || user.balance < input.amount) {
          throw new Error("Insufficient balance");
        }

        await tx.update(users)
          .set({ balance: sql`${users.balance} - ${input.amount}` })
          .where(eq(users.id, ctx.user.userId));
        
        await tx.insert(transactions).values({
          userId: ctx.user.userId,
          amount: -input.amount,
          type: "withdraw",
          reference: "manual_withdraw"
        });
        
        const [updatedUser] = await tx.select().from(users).where(eq(users.id, ctx.user.userId));
        if (!updatedUser) throw new Error("User not found during withdrawal");
        return { balance: updatedUser.balance };
      });
    }),

  playDice: protectedProcedure
    .input(z.object({ 
      bet: z.number().positive(), 
      target: z.number().min(1).max(98), 
      type: z.enum(["over", "under"]) 
    }))
    .mutation(async ({ input, ctx }) => {
      return await db.transaction(async (tx) => {
        const [user] = await tx.select().from(users).where(eq(users.id, ctx.user.userId));
        if (!user || user.balance < input.bet) {
          throw new Error("Insufficient balance");
        }

        const result = await internal.playDice(ctx.user.userId, input.bet, input.target, input.type);
        
        await tx.update(users)
          .set({ balance: sql`${users.balance} + ${result.payout - input.bet}` })
          .where(eq(users.id, ctx.user.userId));

        await tx.insert(transactions).values({
          userId: ctx.user.userId,
          amount: -input.bet,
          type: "bet",
          reference: "dice"
        });

        if (result.payout > 0) {
          await tx.insert(transactions).values({
            userId: ctx.user.userId,
            amount: result.payout,
            type: "win",
            reference: "dice"
          });
        }

        const [updatedUser] = await tx.select().from(users).where(eq(users.id, ctx.user.userId));
        if (!updatedUser) throw new Error("User not found after play");
        return { ...result, newBalance: updatedUser.balance };
      });
    }),
});

export type AppRouter = typeof appRouter;
