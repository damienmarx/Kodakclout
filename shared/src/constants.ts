export const APP_NAME = "Kodakclout";
export const APP_VERSION = "1.0.0";

export const API_PREFIX = "/api";
export const TRPC_PREFIX = "/api/trpc";

export const GAME_CATEGORIES = [
  "slots",
  "table",
  "live",
  "crash",
  "poker",
  "other",
] as const;

export const GAME_PROVIDERS = ["clutch", "internal"] as const;

export const DEFAULT_PAGE_SIZE = 24;
export const MAX_PAGE_SIZE = 100;

export const SESSION_COOKIE_NAME = "kodakclout_session";
export const SESSION_MAX_AGE = 7 * 24 * 60 * 60 * 1000; // 7 days in ms

export const OAUTH_PROVIDERS = {
  GOOGLE: "google",
} as const;
