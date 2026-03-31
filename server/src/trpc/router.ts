import { router, publicProcedure, protectedProcedure } from "./trpc.js";
import { GamesQuery, Session } from "@kodakclout/shared";
import { GamesQuerySchema, GamesListResponseSchema, GameLaunchResponseSchema } from "@kodakclout/shared";
import { ClutchProvider } from "../providers/clutch.js";
import { authRouter } from "./auth.js";
import { z } from "zod";
import { db } from "../db/index.js";
import { users } from "../db/schema.js";
import { eq, sql } from "drizzle-orm";

const clutch = ClutchProvider.getInstance();

export const appRouter = router({
  auth: authRouter,
  getGames: publicProcedure
    .input(GamesQuerySchema)
    .output(GamesListResponseSchema)
    .query(async ({ input }: { input: GamesQuery }) => {
      const { page, pageSize, category, search } = input;
      const allGames = await clutch.getGames();
      
      let filtered = allGames;
      if (category) {
        filtered = filtered.filter(g => g.category === category);
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
      const launch = await clutch.getLaunchUrl(input.slug, ctx.user.userId.toString());
      return launch;
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
      await db.update(users)
        .set({ balance: sql`${users.balance} + ${input.amount}` })
        .where(eq(users.id, ctx.user.userId));
      
      const [user] = await db.select().from(users).where(eq(users.id, ctx.user.userId));
      return { balance: user.balance };
    }),

  withdraw: protectedProcedure
    .input(z.object({ amount: z.number().positive() }))
    .mutation(async ({ input, ctx }) => {
      const [user] = await db.select().from(users).where(eq(users.id, ctx.user.userId));
      if (!user || user.balance < input.amount) {
        throw new Error("Insufficient balance");
      }

      await db.update(users)
        .set({ balance: sql`${users.balance} - ${input.amount}` })
        .where(eq(users.id, ctx.user.userId));
      
      const [updatedUser] = await db.select().from(users).where(eq(users.id, ctx.user.userId));
      return { balance: updatedUser.balance };
    }),
});

export type AppRouter = typeof appRouter;
