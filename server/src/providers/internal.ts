import { Game, GameLaunchResponse } from "@kodakclout/shared";

export class InternalProvider {
  private static instance: InternalProvider;
  
  private constructor() {}

  public static getInstance(): InternalProvider {
    if (!InternalProvider.instance) {
      InternalProvider.instance = new InternalProvider();
    }
    return InternalProvider.instance;
  }

  async getGames(): Promise<Game[]> {
    // These are internal games that don't require external APIs
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
      token: "internal-session-token",
    };
  }

  /**
   * ─── Internal Game Engine ──────────────────────────────────────────────────
   * Logic for standalone games with configurable house edge.
   * ───────────────────────────────────────────────────────────────────────────
   */

  // Dice Logic: Roll 0-100. House edge applied via win probability.
  async playDice(_userId: number, bet: number, target: number, type: "over" | "under") {
    const houseEdge = 0.04; // 4% House Edge
    const roll = Math.random() * 100;
    
    let win = false;
    if (type === "over") {
      win = roll > target;
    } else {
      win = roll < target;
    }

    // Calculate multiplier based on probability
    const probability = type === "over" ? (100 - target) : target;
    const multiplier = (100 / probability) * (1 - houseEdge);
    const payout = win ? bet * multiplier : 0;

    return { roll, win, payout, multiplier: win ? multiplier : 0 };
  }

  // Crash Logic: Random multiplier with house edge.
  async playCrash() {
    const houseEdge = 0.03; // 3% House Edge
    // Classic crash formula: 0.97 / (1 - X) where X is uniform [0, 1)
    const r = Math.random();
    const crashPoint = Math.max(1, (1 - houseEdge) / (1 - r));
    return { crashPoint: parseFloat(crashPoint.toFixed(2)) };
  }
}
