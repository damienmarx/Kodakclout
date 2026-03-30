import axios from "axios";
import { Game, GameLaunchResponse } from "@kodakclout/shared";
import dotenv from "dotenv";

dotenv.config();

const CLUTCH_API_URL = process.env.CLUTCH_API_URL || "https://api.clutch.io";
const CLUTCH_API_KEY = process.env.CLUTCH_API_KEY;

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

  /**
   * Fetches the list of available games from the Clutch engine.
   * Maps Clutch's GameInfo to the Kodakclout Game interface.
   */
  async getGames(): Promise<Game[]> {
    try {
      const response = await this.client.get("/game/list", {
        params: { inc: "all", sort: true }
      });
      
      const clutchGames = response.data.list || [];
      return clutchGames.map((g: any) => ({
        id: g.name, // Using name as ID for Clutch games
        slug: g.name.toLowerCase().replace(/\s+/g, "-"),
        title: g.name,
        provider: "clutch",
        category: "slots", // Clutch is primarily a slots engine
        thumbnail: `/assets/games/${g.name.toLowerCase().replace(/\s+/g, "-")}.png`,
        isActive: true,
      }));
    } catch (error) {
      console.error("Clutch getGames error:", error);
      return [];
    }
  }

  /**
   * Creates a new game session in Clutch and returns the launch parameters.
   */
  async getLaunchUrl(gameSlug: string, userId: string): Promise<GameLaunchResponse> {
    try {
      // 1. Create a new game session (ApiGameNew)
      // For the unified platform, we assume CID 1 is the default club
      // Note: Clutch expects numeric IDs, so we convert userId if needed
      const response = await this.client.post("/game/new", {
        cid: 1,
        uid: parseInt(userId) || 1, // Fallback to 1 for testing
        alias: gameSlug
      });

      const { gid } = response.data;
      
      // The launch URL points to the Clutch UI with the game ID (gid)
      return {
        url: `${CLUTCH_API_URL}/?gid=${gid}&cid=1&uid=${userId}`,
        token: response.data.access,
      };
    } catch (error) {
      console.error("Clutch getLaunchUrl error:", error);
      throw new Error("Failed to launch game from Clutch engine");
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
