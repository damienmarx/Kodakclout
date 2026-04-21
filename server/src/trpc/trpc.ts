import { initTRPC, TRPCError } from "@trpc/server";
import { CreateExpressContextOptions } from "@trpc/server/adapters/express";
import { Session } from "@kodakclout/shared";
import jwt from "jsonwebtoken";
import dotenv from "dotenv";

dotenv.config();

const JWT_SECRET = process.env.JWT_SECRET;

if (!JWT_SECRET && process.env.NODE_ENV === "production") {
  throw new Error("JWT_SECRET must be defined in production environment");
}

const FALLBACK_SECRET = "dev-secret-only";

export const createContext = ({ req, res }: CreateExpressContextOptions) => {
  const token = req.cookies?.kodakclout_session;
  let user: Session | null = null;

  if (token) {
    try {
      user = jwt.verify(token, JWT_SECRET || FALLBACK_SECRET) as Session;
    } catch (err) {
      // Invalid token - silently fail and leave user as null
    }
  }

  return {
    req,
    res,
    user,
  };
};

type Context = Awaited<ReturnType<typeof createContext>>;

const t = initTRPC.context<Context>().create();

export const router = t.router;
export const publicProcedure = t.procedure;

export const protectedProcedure = t.procedure.use(({ ctx, next }) => {
  if (!ctx.user) {
    throw new TRPCError({ code: "UNAUTHORIZED" });
  }
  return next({
    ctx: {
      ...ctx,
      user: ctx.user,
    },
  });
});
