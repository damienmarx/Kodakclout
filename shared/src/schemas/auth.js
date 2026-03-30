"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.OAuthProfileSchema = exports.SessionSchema = exports.UserSchema = void 0;
const zod_1 = require("zod");
exports.UserSchema = zod_1.z.object({
    id: zod_1.z.number(),
    email: zod_1.z.string().email(),
    name: zod_1.z.string(),
    avatar: zod_1.z.string().url().optional(),
    createdAt: zod_1.z.date(),
    updatedAt: zod_1.z.date(),
});
exports.SessionSchema = zod_1.z.object({
    userId: zod_1.z.number(),
    email: zod_1.z.string().email(),
    name: zod_1.z.string(),
    avatar: zod_1.z.string().url().optional(),
    expiresAt: zod_1.z.date(),
});
exports.OAuthProfileSchema = zod_1.z.object({
    id: zod_1.z.string(),
    email: zod_1.z.string().email(),
    name: zod_1.z.string(),
    picture: zod_1.z.string().url().optional(),
    provider: zod_1.z.literal("google"),
});
