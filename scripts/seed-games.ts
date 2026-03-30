import { db } from "../server/src/db/index.js";
import { games } from "../server/src/db/schema.js";
import { ClutchProvider } from "../server/src/providers/clutch.js";
import { eq } from "drizzle-orm";

async function seed() {
  console.log("🚀 Starting game sync from Clutch engine...");
  
  const clutch = ClutchProvider.getInstance();
  const clutchGames = await clutch.getGames();
  
  if (clutchGames.length === 0) {
    console.error("❌ No games found in Clutch. Is the engine running?");
    process.exit(1);
  }

  console.log(`🔍 Found ${clutchGames.length} games in Clutch. Syncing to database...`);

  for (const game of clutchGames) {
    try {
      // Check if game already exists
      const existing = await db.query.games.findFirst({
        where: eq(games.slug, game.slug)
      });

      if (existing) {
        console.log(`  - Updating existing game: ${game.title}`);
        await db.update(games)
          .set({
            title: game.title,
            provider: game.provider,
            category: game.category,
            thumbnail: game.thumbnail,
            isActive: true
          })
          .where(eq(games.slug, game.slug));
      } else {
        console.log(`  + Inserting new game: ${game.title}`);
        await db.insert(games).values({
          id: game.id,
          slug: game.slug,
          title: game.title,
          provider: game.provider,
          category: game.category,
          thumbnail: game.thumbnail,
          isActive: true,
          isNew: true
        });
      }
    } catch (err) {
      console.error(`  ! Error syncing game ${game.title}:`, err);
    }
  }

  console.log("✅ Game sync complete!");
  process.exit(0);
}

seed().catch(err => {
  console.error("❌ Fatal error during seeding:", err);
  process.exit(1);
});
