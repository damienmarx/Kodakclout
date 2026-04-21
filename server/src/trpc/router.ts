import { router, publicProcedure, protectedProcedure } from "./trpc.js";
import { GamesQuery, Session } from "@kodakclout/shared";
import { GamesQuerySchema, GamesListResponseSchema, GameLaunchResponseSchema } from "@kodakclout/shared";
import { ClutchProvider } from "../providers/clutch.js";
import { InternalProvider } from "../providers/internal.js";
import { authRouter } from "./auth.js";
import { adminRouter } from "./admin.js";
import { z } from "zod";
import { db } from "../db/index.js";
import { users, transactions } from "../db/schema.js";
import { eq, sql } from "drizzle-orm";

const clutch = ClutchProvider.getInstance();
const internal = InternalProvider.getInstance();

export const appRouter = router({
  auth: authRouter,
  admin: adminRouter,
  getGames: publicProcedure
    .input(GamesQuerySchema)
    .output(GamesListResponseSchema)
    .query(async ({ input }: { input: GamesQuery }) => {
      const { page, pageSize, category, search, provider } = input;
      
      const [clutchGames, internalGames] = await Promise.all([
        clutch.getGames(),
        internal.getGames()
      ]);
      
      let allGames = [...internalGames, ...clutchGames];
      
      let filtered = allGames;
      if (category) {
        filtered = filtered.filter(g => g.category === category);
      }
      if (provider) {
        filtered = filtered.filter(g => g.provider === provider);
      }
      if (search) {
        const lowerSearch = search.toLowerCase();
        filtered = filtered.filter(g => 
          g.title.toLowerCase().includes(lowerSearch) || 
          g.slug.toLowerCase().includes(lowerSearch)
        );
      }

      const total = filtered.length;
      const start = (page - 1) * pageSize;
      const paginated = filtered.slice(start, start + pageSize);

      return {
        games: paginated,
        total,
        page,
        pageSize
      };
    }),

  launchGame: protectedProcedure
    .input(z.object({ slug: z.string() }))
    .output(GameLaunchResponseSchema)
    .mutation(async ({ input, ctx }: { input: { slug: string }, ctx: { user: Session } }) => {
      const internalGames = await internal.getGames();
      const isInternal = internalGames.some(g => g.slug === input.slug);
      
      if (isInternal) {
        return await internal.getLaunchUrl(input.slug, ctx.user.userId.toString());
      }
      
      return await clutch.getLaunchUrl(input.slug, ctx.user.userId.toString());
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
