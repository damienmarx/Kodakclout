import axios from "axios";
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
      },
      timeout: 5000
    });
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
