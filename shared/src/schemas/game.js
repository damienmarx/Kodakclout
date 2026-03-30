"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.GamesQuerySchema = exports.GameLaunchResponseSchema = exports.GamesListResponseSchema = exports.GameSchema = exports.GameProviderSchema = exports.GameCategorySchema = void 0;
const zod_1 = require("zod");
exports.GameCategorySchema = zod_1.z.enum([
    "slots",
    "table",
    "live",
    "crash",
    "poker",
    "other",
]);
exports.GameProviderSchema = zod_1.z.enum(["clutch", "internal"]);
exports.GameSchema = zod_1.z.object({
    id: zod_1.z.string(),
    slug: zod_1.z.string(),
    title: zod_1.z.string(),
    provider: exports.GameProviderSchema,
    category: exports.GameCategorySchema,
    thumbnail: zod_1.z.string().url().or(zod_1.z.string().startsWith("/")),
    description: zod_1.z.string().optional(),
    tags: zod_1.z.array(zod_1.z.string()).optional(),
    isNew: zod_1.z.boolean().optional(),
    isHot: zod_1.z.boolean().optional(),
    isActive: zod_1.z.boolean(),
});
exports.GamesListResponseSchema = zod_1.z.object({
    games: zod_1.z.array(exports.GameSchema),
    total: zod_1.z.number(),
    page: zod_1.z.number(),
    pageSize: zod_1.z.number(),
});
exports.GameLaunchResponseSchema = zod_1.z.object({
    url: zod_1.z.string().url(),
    token: zod_1.z.string().optional(),
    expiresAt: zod_1.z.string().optional(),
});
exports.GamesQuerySchema = zod_1.z.object({
    page: zod_1.z.number().min(1).default(1),
    pageSize: zod_1.z.number().min(1).max(100).default(24),
    category: exports.GameCategorySchema.optional(),
    provider: exports.GameProviderSchema.optional(),
    search: zod_1.z.string().optional(),
});
