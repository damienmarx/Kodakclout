import { z } from "zod";

export const UserSchema = z.object({
  id: z.number(),
  email: z.string().email(),
  name: z.string(),
  avatar: z.string().url().optional(),
  createdAt: z.date(),
  updatedAt: z.date(),
});

export const SessionSchema = z.object({
  userId: z.number(),
  email: z.string().email(),
  name: z.string(),
  avatar: z.string().url().optional(),
  expiresAt: z.date(),
});

export const OAuthProfileSchema = z.object({
  id: z.string(),
  email: z.string().email(),
  name: z.string(),
  picture: z.string().url().optional(),
  provider: z.literal("google"),
});
