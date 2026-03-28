export type GameCategory =
  | "slots"
  | "table"
  | "live"
  | "crash"
  | "poker"
  | "other";

export type GameProvider = "clutch" | "internal";

export interface Game {
  id: string;
  slug: string;
  title: string;
  provider: GameProvider;
  category: GameCategory;
  thumbnail: string;
  description?: string;
  tags?: string[];
  isNew?: boolean;
  isHot?: boolean;
  isActive: boolean;
}

export interface GameLaunchResponse {
  url: string;
  token?: string;
  expiresAt?: string;
}

export interface GamesListResponse {
  games: Game[];
  total: number;
  page: number;
  pageSize: number;
}
