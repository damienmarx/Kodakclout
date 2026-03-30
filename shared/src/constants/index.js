"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.OAUTH_PROVIDERS = exports.SESSION_MAX_AGE = exports.SESSION_COOKIE_NAME = exports.MAX_PAGE_SIZE = exports.DEFAULT_PAGE_SIZE = exports.GAME_PROVIDERS = exports.GAME_CATEGORIES = exports.TRPC_PREFIX = exports.API_PREFIX = exports.APP_VERSION = exports.APP_NAME = void 0;
exports.APP_NAME = "Kodakclout";
exports.APP_VERSION = "1.0.0";
exports.API_PREFIX = "/api";
exports.TRPC_PREFIX = "/api/trpc";
exports.GAME_CATEGORIES = [
    "slots",
    "table",
    "live",
    "crash",
    "poker",
    "other",
];
exports.GAME_PROVIDERS = ["clutch", "internal"];
exports.DEFAULT_PAGE_SIZE = 24;
exports.MAX_PAGE_SIZE = 100;
exports.SESSION_COOKIE_NAME = "kodakclout_session";
exports.SESSION_MAX_AGE = 7 * 24 * 60 * 60 * 1000; // 7 days in ms
exports.OAUTH_PROVIDERS = {
    GOOGLE: "google",
};
