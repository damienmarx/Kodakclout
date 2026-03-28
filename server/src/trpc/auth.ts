import { router, publicProcedure } from "./trpc.js";
import { z } from "zod";
import { TRPCError } from "@trpc/server";
import { db } from "../db/index.js";
import { users } from "../db/schema.js";
import { eq } from "drizzle-orm";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import { SESSION_COOKIE_NAME, SESSION_MAX_AGE } from "@kodakclout/shared";

const JWT_SECRET = process.env.JWT_SECRET || "kodakclout-secret-key-damien";
const SALT_ROUNDS = parseInt(process.env.PASSWORD_SALT_ROUNDS || "12");

export const authRouter = router({
  register: publicProcedure
    .input(z.object({
      email: z.string().email(),
      password: z.string().min(8),
      name: z.string().min(2),
    }))
    .mutation(async ({ input }) => {
      const existingUser = await db.query.users.findFirst({
        where: eq(users.email, input.email),
      });

      if (existingUser) {
        throw new TRPCError({
          code: "CONFLICT",
          message: "User already exists with this email",
        });
      }

      const hashedPassword = await bcrypt.hash(input.password, SALT_ROUNDS);

      const [result] = await db.insert(users).values({
        email: input.email,
        password: hashedPassword,
        name: input.name,
      });

      return { success: true, userId: result.insertId };
    }),

  login: publicProcedure
    .input(z.object({
      email: z.string().email(),
      password: z.string(),
    }))
    .mutation(async ({ input, ctx }) => {
      const user = await db.query.users.findFirst({
        where: eq(users.email, input.email),
      });

      if (!user || !user.password) {
        throw new TRPCError({
          code: "UNAUTHORIZED",
          message: "Invalid email or password",
        });
      }

      const isPasswordValid = await bcrypt.compare(input.password, user.password);

      if (!isPasswordValid) {
        throw new TRPCError({
          code: "UNAUTHORIZED",
          message: "Invalid email or password",
        });
      }

      const sessionData = {
        userId: user.id,
        email: user.email,
        name: user.name,
        avatar: user.avatar,
        expiresAt: new Date(Date.now() + SESSION_MAX_AGE),
      };

      const token = jwt.sign(sessionData, JWT_SECRET);

      ctx.res.cookie(SESSION_COOKIE_NAME, token, {
        httpOnly: true,
        secure: process.env.NODE_ENV === "production",
        sameSite: "lax",
        maxAge: SESSION_MAX_AGE,
      });

      return { success: true, user: sessionData };
    }),

  logout: publicProcedure.mutation(({ ctx }) => {
    ctx.res.clearCookie(SESSION_COOKIE_NAME);
    return { success: true };
  }),
});
