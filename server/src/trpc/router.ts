import { router, publicProcedure, protectedProcedure } from "./trpc.js";
import { GamesQuery, Session } from "@kodakclout/shared";
import { GamesQuerySchema, GamesListResponseSchema, GameLaunchResponseSchema } from "@kodakclout/shared";
import { ClutchProvider } from "../providers/clutch.js";
import { authRouter } from "./auth.js";
import { z } from "zod";

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

  me: publicProcedure.query(({ ctx }: { ctx: { user: Session | null } }) => {
    return ctx.user;
  }),
});

export type AppRouter = typeof appRouter;
