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

  async getGames(): Promise<Game[]> {
    try {
      // In a real scenario, we'd fetch from Clutch API
      // For now, returning mock data that matches the shared schema
      // In production, this would be: const response = await this.client.get("/games");
      
      return [
        {
          id: "cl-1",
          slug: "clutch-slots-1",
          title: "Clutch Slots Deluxe",
          provider: "clutch",
          category: "slots",
          thumbnail: "https://placehold.co/400x300/1a1a1a/ffffff?text=Clutch+Slots",
          isActive: true,
          isHot: true
        },
        {
          id: "cl-2",
          slug: "clutch-roulette",
          title: "Pro Roulette",
          provider: "clutch",
          category: "table",
          thumbnail: "https://placehold.co/400x300/1a1a1a/ffffff?text=Roulette",
          isActive: true
        }
      ];
    } catch (error) {
      console.error("Clutch getGames error:", error);
      return [];
    }
  }

  async getLaunchUrl(gameSlug: string, userId: string): Promise<GameLaunchResponse> {
    try {
      // Production: const response = await this.client.post(`/games/${gameSlug}/launch`, { userId });
      // return response.data;
      
      return {
        url: `https://clutch.io/play/${gameSlug}?token=mock_token_${userId}`,
        token: `mock_token_${userId}`
      };
    } catch (error) {
      console.error("Clutch getLaunchUrl error:", error);
      throw new Error("Failed to launch game from provider");
    }
  }

  async validateToken(token: string): Promise<boolean> {
    try {
      // Production: const response = await this.client.post("/auth/validate", { token });
      // return response.data.valid;
      return true;
    } catch (error) {
      return false;
    }
  }
}
