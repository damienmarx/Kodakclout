import { router, publicProcedure, protectedProcedure } from "./trpc.js";
import { GamesQuery, Session } from "@kodakclout/shared";
import { GamesQuerySchema, GamesListResponseSchema, GameLaunchResponseSchema } from "@kodakclout/shared";
import { ClutchProvider } from "../providers/clutch.js";
import { InternalProvider } from "../providers/internal.js";
import { authRouter } from "./auth.js";
import { adminRouter } from "./admin.js";
import { z } from "zod";
import { db, createConnection } from "../db/index.js"; // Import createConnection
import { users, transactions } from "../db/schema.js";
import { eq, sql } from "drizzle-orm";
import mysql from "mysql2/promise"; // Import mysql2

const clutch = ClutchProvider.getInstance();
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

      // Fetch games directly using mysql2 to bypass Drizzle ORM issue
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
        WHERE 1=1
        ${category ? `AND category = ${rawPool.escape(category)}` : ''}
        ${provider ? `AND provider = ${rawPool.escape(provider)}` : ''}
        ${search ? `AND (title LIKE ${rawPool.escape(`%${search}%`)} OR slug LIKE ${rawPool.escape(`%${search}%`)})` : ''}
        LIMIT ? OFFSET ?
      `, [pageSize, (page - 1) * pageSize]);

      const [totalRows] = await rawPool.execute<mysql.RowDataPacket[]>(`
        SELECT COUNT(*) as count
        FROM games
        WHERE 1=1
        ${category ? `AND category = ${rawPool.escape(category)}` : ''}
        ${provider ? `AND provider = ${rawPool.escape(provider)}` : ''}
        ${search ? `AND (title LIKE ${rawPool.escape(`%${search}%`)} OR slug LIKE ${rawPool.escape(`%${search}%`)})` : ''}
      `);
      const total = (totalRows[0] as { count: number }).count;

      const games = rows.map(row => ({
        id: row.id,
        slug: row.slug,
        title: row.title,
        provider: row.provider === 'clutch' ? 'clutch' : 'internal', // Ensure provider is 'clutch' or 'internal'
        category: row.category || 'slots', // Fallback to 'slots' if NULL
        thumbnail: row.thumbnail,
        description: row.description,
        isNew: !!row.isNew, // Convert 1/0 to true/false
        isHot: !!row.isHot, // Convert 1/0 to true/false
        isActive: !!row.isActive, // Convert 1/0 to true/false
        clutchAlias: row.clutchAlias, // Include clutchAlias
      }));

      return {
        games: games,
        total,
        page,
        pageSize
      };
    }),

  launchGame: publicProcedure // Changed to publicProcedure as per requirements
    .input(z.object({ slug: z.string() }))
    .output(GameLaunchResponseSchema)
    .mutation(async ({ input, ctx }: { input: { slug: string }, ctx: { user?: Session } }) => { // user is optional now
      const internalGames = await internal.getGames();
      const isInternal = internalGames.some(g => g.slug === input.slug);
      
      if (isInternal) {
        // For internal games, user ID is not strictly required for MVP, but keeping it for consistency
        return await internal.getLaunchUrl(input.slug, ctx.user?.userId?.toString() || '1'); 
      }
      
      // Fetch clutch_alias from the database
      const [gameRows] = await rawPool.execute<mysql.RowDataPacket[]>(`
        SELECT clutch_alias FROM games WHERE slug = ?
      `, [input.slug]);

      if (gameRows.length === 0 || !gameRows[0].clutch_alias) {
        throw new Error(`Clutch game with slug ${input.slug} not found or missing clutch_alias`);
      }
      const clutchAlias = gameRows[0].clutch_alias;

      // Generate JWT for Clutch games
      const JWT_SECRET = process.env.CLUTCH_API_KEY || "local-clutch-key"; // Use CLUTCH_API_KEY as secret
      const now = Math.floor(Date.now() / 1000);
      const exp = now + 300; // 5 minutes expiration
      const token = jwt.sign(
        { uid: ctx.user?.userId || 1, cid: 1, iss: 'slotopol', exp: exp }, // Default uid to 1 if not logged in
        JWT_SECRET
      );

      // POST to http://localhost:8081/game/new
      const clutchResponse = await axios.post(
        `${process.env.CLUTCH_API_URL || 'http://localhost:8081'}/game/new`,
        { cid: 1, uid: ctx.user?.userId || 1, alias: clutchAlias },
        { headers: { 'Authorization': `Bearer ${token}` } }
      );
      const { gid } = clutchResponse.data;

      // Return iframe URL
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

  // ─── Internal Games ────────────────────────────────────────────────────────
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
        
        // Update balance atomically
        const balanceChange = result.payout - input.bet;
        await tx.update(users)
          .set({ balance: sql`${users.balance} + ${balanceChange}` })
          .where(eq(users.id, ctx.user.userId));

        // Log bet
        await tx.insert(transactions).values({
          userId: ctx.user.userId,
          amount: -input.bet,
          type: "bet",
          reference: "dice"
        });

        // Log win if any
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
