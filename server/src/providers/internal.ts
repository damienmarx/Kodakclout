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
    // For internal games, we point to our own internal game engine/UI
    // This will be implemented as a separate route or client-side component
    return {
      url: `/play/${gameSlug}?uid=${userId}`,
      token: "internal-session-token",
    };
  }
}
