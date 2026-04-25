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

  // getGames method is removed as it's now handled directly in router.ts
  // getLaunchUrl method is removed as it's now handled directly in router.ts

  async validateToken(token: string): Promise<boolean> {
    try {
      const response = await this.client.post<{ valid: boolean }>("/auth/validate", { token });
      return response.data.valid;
    } catch {
      return false;
    }
  }
}
