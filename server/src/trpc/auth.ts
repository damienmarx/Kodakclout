import { router, publicProcedure } from "./trpc.js";
import { z } from "zod";
import { TRPCError } from "@trpc/server";
import { db } from "../db/index.js";
import { users } from "../db/schema.js";
import { eq } from "drizzle-orm";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import { SESSION_COOKIE_NAME, SESSION_MAX_AGE } from "@kodakclout/shared";

const SALT_ROUNDS = parseInt(process.env.SALT_ROUNDS || "12");
const JWT_SECRET = process.env.JWT_SECRET || "dev-secret-only";

export const authRouter = router({
  register: publicProcedure
    .input(z.object({
      email: z.string().email(),
      password: z.string().min(8),
      name: z.string().min(2),
    }))
    .mutation(async ({ input }) => {
      const existingUser = await db.select().from(users).where(eq(users.email, input.email));
      if (existingUser.length > 0) {
        throw new TRPCError({
          code: "CONFLICT",
          message: "Email already in use",
        });
      }

      const hashedPassword = await bcrypt.hash(input.password, SALT_ROUNDS);
      
      await db.insert(users).values({
        email: input.email,
        password: hashedPassword,
        name: input.name,
        balance: 1000, // Starting balance for new users
      });

      return { success: true };
    }),

  login: publicProcedure
    .input(z.object({
      email: z.string().email(),
      password: z.string(),
    }))
    .mutation(async ({ input, ctx }) => {
      const [user] = await db.select().from(users).where(eq(users.email, input.email));
      if (!user || !user.password) {
        throw new TRPCError({
          code: "UNAUTHORIZED",
          message: "Invalid email or password",
        });
      }

      const validPassword = await bcrypt.compare(input.password, user.password);
      if (!validPassword) {
        throw new TRPCError({
          code: "UNAUTHORIZED",
          message: "Invalid email or password",
        });
      }

      const session = {
        userId: user.id,
        email: user.email,
        name: user.name,
        avatar: user.avatar || undefined,
        expiresAt: new Date(Date.now() + SESSION_MAX_AGE),
      };

      const token = jwt.sign(session, JWT_SECRET);

      ctx.res.cookie(SESSION_COOKIE_NAME, token, {
        httpOnly: true,
        secure: process.env.NODE_ENV === "production",
        sameSite: "lax",
        maxAge: SESSION_MAX_AGE,
      });

      return {
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          avatar: user.avatar,
          balance: user.balance,
        }
      };
    }),

  logout: publicProcedure.mutation(async ({ ctx }) => {
    ctx.res.clearCookie(SESSION_COOKIE_NAME);
    return { success: true };
  }),
});
