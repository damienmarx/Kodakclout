import { Game, GameLaunchResponse } from "@kodakclout/shared";
import crypto from "crypto";

export class InternalProvider {
  private static instance: InternalProvider;
  
  private constructor() {}

  public static getInstance(): InternalProvider {
    if (!InternalProvider.instance) {
      InternalProvider.instance = new InternalProvider();
    }
    return InternalProvider.instance;
  }

  /**
   * Secure Random Number Generation
   * Returns a float between 0 and 1
   */
  private secureRandom(): number {
    return crypto.randomBytes(4).readUInt32BE(0) / 0xffffffff;
  }

  async getGames(): Promise<Game[]> {
    return [
      {
        id: "internal-dice",
        slug: "dice",
        title: "Clout Dice",
        provider: "internal",
        category: "other",
        thumbnail: "/assets/games/dice.png",
        isActive: true,
        isHot: true,
      },
      {
        id: "internal-crash",
        slug: "crash",
        title: "Clout Crash",
        provider: "internal",
        category: "crash",
        thumbnail: "/assets/games/crash.png",
        isActive: true,
        isNew: true,
      },
      {
        id: "internal-limbo",
        slug: "limbo",
        title: "Clout Limbo",
        provider: "internal",
        category: "other",
        thumbnail: "/assets/games/limbo.png",
        isActive: true,
      }
    ];
  }

  async getLaunchUrl(gameSlug: string, userId: string): Promise<GameLaunchResponse> {
    return {
      url: `/play/${gameSlug}?uid=${userId}`,
      token: crypto.randomUUID(),
    };
  }

  /**
   * ─── Internal Game Engine ──────────────────────────────────────────────────
   * Logic for standalone games with secure RNG and configurable house edge.
   * ───────────────────────────────────────────────────────────────────────────
   */

  // Dice Logic: Roll 0-100. House edge applied via win probability.
  async playDice(_userId: number, bet: number, target: number, type: "over" | "under") {
    const houseEdge = 0.04; // 4% House Edge
    const roll = this.secureRandom() * 100;
    
    let win = false;
    if (type === "over") {
      win = roll > target;
    } else {
      win = roll < target;
    }

    // Calculate multiplier based on probability
    const probability = type === "over" ? (100 - target) : target;
    // Multiplier = (1 / Prob) * (1 - Edge)
    const multiplier = (100 / probability) * (1 - houseEdge);
    const payout = win ? bet * multiplier : 0;

    return { 
      roll: parseFloat(roll.toFixed(2)), 
      win, 
      payout: Math.floor(payout), // Assuming balance is in integers (cents)
      multiplier: win ? parseFloat(multiplier.toFixed(4)) : 0 
    };
  }

  // Crash Logic: Random multiplier with house edge.
  async playCrash() {
    const houseEdge = 0.03; // 3% House Edge
    // Classic crash formula: (1 - Edge) / (1 - X) where X is uniform [0, 1)
    const r = this.secureRandom();
    // 0.0001 added to avoid division by zero in extreme cases
    const crashPoint = Math.max(1, (1 - houseEdge) / (1 - r + 0.0001));
    return { crashPoint: parseFloat(crashPoint.toFixed(2)) };
  }
}
