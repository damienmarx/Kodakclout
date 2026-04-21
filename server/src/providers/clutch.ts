import axios from "axios";
import { Game, GameLaunchResponse } from "@kodakclout/shared";
import dotenv from "dotenv";

dotenv.config();

const CLUTCH_API_URL = process.env.CLUTCH_API_URL || "http://localhost:8081";
const CLUTCH_API_KEY = process.env.CLUTCH_API_KEY || "local-clutch-key";

interface ClutchGame {
  name: string;
  [key: string]: unknown;
}

export class ClutchProvider {
  private static instance: ClutchProvider;
  
  private constructor() {}

  public static getInstance(): ClutchProvider {
    if (!ClutchProvider.instance) {
      ClutchProvider.instance = new ClutchProvider();
    }
    return ClutchProvider.instance;
  }

  private get client() {
    return axios.create({
      baseURL: CLUTCH_API_URL,
      headers: {
        "Authorization": `Bearer ${CLUTCH_API_KEY}`,
        "Content-Type": "application/json"
      },
      timeout: 5000
    });
  }

  async getGames(): Promise<Game[]> {
    try {
      const response = await this.client.get<{ list: ClutchGame[] }>("/game/list", {
        params: { inc: "all", sort: true }
      });
      
      const clutchGames = response.data.list || [];
      return clutchGames.map((g: ClutchGame) => ({
        id: g.name,
        slug: g.name.toLowerCase().replace(/\s+/g, "-"),
        title: g.name,
        provider: "clutch",
        category: "slots",
        thumbnail: `/assets/games/${g.name.toLowerCase().replace(/\s+/g, "-")}.png`,
        isActive: true,
      }));
    } catch (error) {
      const message = error instanceof Error ? error.message : "Unknown error";
      // Using a structured logger or silent fail for production-readiness
      if (process.env.NODE_ENV !== "production") {
        console.error(`[Clutch] getGames failed: ${message}`);
      }
      return [];
    }
  }

  async getLaunchUrl(gameSlug: string, userId: string): Promise<GameLaunchResponse> {
    try {
      const response = await this.client.post<{ gid: string; access: string }>("/game/new", {
        cid: 1,
        uid: parseInt(userId) || 1,
        alias: gameSlug
      });

      const { gid, access } = response.data;
      
      return {
        url: `${CLUTCH_API_URL}/?gid=${gid}&cid=1&uid=${userId}`,
        token: access,
      };
    } catch (error) {
      const message = error instanceof Error ? error.message : "Unknown error";
      if (process.env.NODE_ENV !== "production") {
        console.error(`[Clutch] getLaunchUrl failed: ${message}`);
      }
      throw new Error("Game service currently unavailable. Please try again later.");
    }
  }

  async validateToken(token: string): Promise<boolean> {
    try {
      const response = await this.client.post<{ valid: boolean }>("/auth/validate", { token });
      return response.data.valid;
    } catch {
      return false;
    }
  }
}
