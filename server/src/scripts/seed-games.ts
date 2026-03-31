import { db } from "../db/index.js";
import { games } from "../db/schema.js";
import dotenv from "dotenv";

dotenv.config();

// Sample game data to seed into the database
const sampleGames = [
  {
    id: "game_001",
    slug: "book-of-ra",
    title: "Book of Ra",
    provider: "clutch",
    category: "slots",
    thumbnail: "/assets/games/book-of-ra.png",
    description: "Classic Egyptian-themed slot machine with expanding symbols",
    isActive: true,
    isNew: false,
    isHot: true,
  },
  {
    id: "game_002",
    slug: "starburst",
    title: "Starburst",
    provider: "clutch",
    category: "slots",
    thumbnail: "/assets/games/starburst.png",
    description: "Vibrant space-themed slot with expanding wilds",
    isActive: true,
    isNew: false,
    isHot: true,
  },
  {
    id: "game_003",
    slug: "gonzo-quest",
    title: "Gonzo's Quest",
    provider: "clutch",
    category: "slots",
    thumbnail: "/assets/games/gonzo-quest.png",
    description: "Adventure-themed slot with cascading reels",
    isActive: true,
    isNew: true,
    isHot: false,
  },
  {
    id: "game_004",
    slug: "blackjack-pro",
    title: "Blackjack Pro",
    provider: "clutch",
    category: "table",
    thumbnail: "/assets/games/blackjack-pro.png",
    description: "Professional blackjack with multiple hand options",
    isActive: true,
    isNew: false,
    isHot: false,
  },
  {
    id: "game_005",
    slug: "roulette-live",
    title: "Roulette Live",
    provider: "clutch",
    category: "live",
    thumbnail: "/assets/games/roulette-live.png",
    description: "Live roulette with professional dealers",
    isActive: true,
    isNew: false,
    isHot: true,
  },
  {
    id: "game_006",
    slug: "crash-game",
    title: "Crash",
    provider: "clutch",
    category: "crash",
    thumbnail: "/assets/games/crash-game.png",
    description: "Fast-paced crash game with multipliers",
    isActive: true,
    isNew: true,
    isHot: true,
  },
  {
    id: "game_007",
    slug: "texas-holdem",
    title: "Texas Hold'em",
    provider: "clutch",
    category: "poker",
    thumbnail: "/assets/games/texas-holdem.png",
    description: "Classic Texas Hold'em poker game",
    isActive: true,
    isNew: false,
    isHot: false,
  },
  {
    id: "game_008",
    slug: "lucky-spin",
    title: "Lucky Spin",
    provider: "clutch",
    category: "slots",
    thumbnail: "/assets/games/lucky-spin.png",
    description: "High-volatility slot with big win potential",
    isActive: true,
    isNew: true,
    isHot: true,
  },
];

async function seedGames() {
  try {
    console.log("Starting game seeding...");

    // Clear existing games (optional - comment out to keep existing data)
    // await db.delete(games);

    // Insert games
    for (const game of sampleGames) {
      const existing = await db.query.games.findFirst({
        where: (games, { eq }) => eq(games.id, game.id),
      });

      if (!existing) {
        await db.insert(games).values(game);
        console.log(`✓ Seeded game: ${game.title}`);
      } else {
        console.log(`⊘ Game already exists: ${game.title}`);
      }
    }

    console.log("Game seeding completed successfully!");
    process.exit(0);
  } catch (error) {
    console.error("Error seeding games:", error);
    process.exit(1);
  }
}

seedGames();
