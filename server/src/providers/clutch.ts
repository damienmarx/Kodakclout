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
      const response = await this.client.get("/games");
      return response.data;
    } catch (error) {
      console.error("Clutch getGames error:", error);
      return [];
    }
  }

  async getLaunchUrl(gameSlug: string, userId: string): Promise<GameLaunchResponse> {
    try {
      const response = await this.client.post(`/games/${gameSlug}/launch`, { userId });
      return response.data;
    } catch (error) {
      console.error("Clutch getLaunchUrl error:", error);
      throw new Error("Failed to launch game from provider");
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
