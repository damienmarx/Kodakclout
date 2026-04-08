import axios from "axios";
import { Game, GameLaunchResponse } from "@kodakclout/shared";
import dotenv from "dotenv";

dotenv.config();

const CLUTCH_API_URL = process.env.CLUTCH_API_URL || "http://localhost:8081";
const CLUTCH_API_KEY = process.env.CLUTCH_API_KEY || "local-clutch-key";

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
      }
    });
  }

  async getGames(): Promise<Game[]> {
    try {
      const response = await this.client.get("/game/list", {
        params: { inc: "all", sort: true }
      });
      
      const clutchGames = response.data.list || [];
      return clutchGames.map((g: any) => ({
        id: g.name,
        slug: g.name.toLowerCase().replace(/\s+/g, "-"),
        title: g.name,
        provider: "clutch",
        category: "slots",
        thumbnail: `/assets/games/${g.name.toLowerCase().replace(/\s+/g, "-")}.png`,
        isActive: true,
      }));
    } catch (error) {
      console.error("Clutch getGames error (local):", error.message);
      return [];
    }
  }

  async getLaunchUrl(gameSlug: string, userId: string): Promise<GameLaunchResponse> {
    try {
      const response = await this.client.post("/game/new", {
        cid: 1,
        uid: parseInt(userId) || 1,
        alias: gameSlug
      });

      const { gid } = response.data;
      
      return {
        url: `${CLUTCH_API_URL}/?gid=${gid}&cid=1&uid=${userId}`,
        token: response.data.access,
      };
    } catch (error) {
      console.error("Clutch getLaunchUrl error (local):", error.message);
      throw new Error("Failed to launch game from local Clutch engine");
    }
  }

  async validateToken(token: string): Promise<boolean> {
    try {
      const response = await this.client.post("/auth/validate", { token });
      return response.data.valid;
    } catch (error) {
      return false;
    }
  }
}
