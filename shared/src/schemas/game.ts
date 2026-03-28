import { z } from "zod";

export const GameCategorySchema = z.enum([
  "slots",
  "table",
  "live",
  "crash",
  "poker",
  "other",
]);

export const GameProviderSchema = z.enum(["clutch", "internal"]);

export const GameSchema = z.object({
  id: z.string(),
  slug: z.string(),
  title: z.string(),
  provider: GameProviderSchema,
  category: GameCategorySchema,
  thumbnail: z.string().url().or(z.string().startsWith("/")),
  description: z.string().optional(),
  tags: z.array(z.string()).optional(),
  isNew: z.boolean().optional(),
  isHot: z.boolean().optional(),
  isActive: z.boolean(),
});

export const GamesListResponseSchema = z.object({
  games: z.array(GameSchema),
  total: z.number(),
  page: z.number(),
  pageSize: z.number(),
});

export const GameLaunchResponseSchema = z.object({
  url: z.string().url(),
  token: z.string().optional(),
  expiresAt: z.string().optional(),
});

export const GamesQuerySchema = z.object({
  page: z.number().min(1).default(1),
  pageSize: z.number().min(1).max(100).default(24),
  category: GameCategorySchema.optional(),
  provider: GameProviderSchema.optional(),
  search: z.string().optional(),
});

export type GamesQuery = z.infer<typeof GamesQuerySchema>;
