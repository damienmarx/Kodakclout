import { useState } from "react";
import { Link } from "react-router-dom";
import { Search, Filter, Play, Star, Flame, Clock } from "lucide-react";
import { trpc } from "../lib/trpc";
import { APP_NAME, GAME_CATEGORIES } from "@kodakclout/shared";

export default function Games() {
  const [search, setSearch] = useState("");
  const [category, setCategory] = useState<string | undefined>(undefined);

  const { data, isLoading } = trpc.getGames.useQuery({
    search: search || undefined,
    category: category as any,
    page: 1,
    pageSize: 48,
  });

  return (
    <div className="min-h-screen bg-zinc-950 flex flex-col">
      <nav className="border-b border-zinc-900 bg-zinc-950/80 backdrop-blur-md sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-4 h-16 flex items-center justify-between gap-4">
          <Link to="/home" className="text-xl font-bold tracking-tighter shrink-0">{APP_NAME}</Link>
          
          <div className="flex-1 max-w-xl relative group">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-500 group-focus-within:text-indigo-400 transition-colors" />
            <input 
              type="text" 
              placeholder="Search for games..."
              className="w-full bg-zinc-900 border border-zinc-800 rounded-xl py-2 pl-10 pr-4 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500/20 focus:border-indigo-500/50 transition-all"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>

          <div className="flex items-center gap-4 shrink-0">
            <button className="p-2 text-zinc-400 hover:text-white transition-colors md:hidden">
              <Filter className="w-5 h-5" />
            </button>
            <Link to="/login" className="text-sm font-semibold hover:text-white text-zinc-400 transition-colors">Sign In</Link>
          </div>
        </div>
      </nav>

      <main className="flex-1 max-w-7xl mx-auto w-full px-4 py-8 space-y-8">
        <div className="flex items-center gap-2 overflow-x-auto pb-4 scrollbar-hide no-scrollbar">
          <button 
            onClick={() => setCategory(undefined)}
            className={`px-4 py-2 rounded-full text-sm font-medium whitespace-nowrap transition-all ${!category ? 'bg-indigo-600 text-white' : 'bg-zinc-900 text-zinc-400 hover:bg-zinc-800 hover:text-zinc-200'}`}
          >
            All Games
          </button>
          {GAME_CATEGORIES.map((cat) => (
            <button 
              key={cat}
              onClick={() => setCategory(cat)}
              className={`px-4 py-2 rounded-full text-sm font-medium whitespace-nowrap capitalize transition-all ${category === cat ? 'bg-indigo-600 text-white' : 'bg-zinc-900 text-zinc-400 hover:bg-zinc-800 hover:text-zinc-200'}`}
            >
              {cat}
            </button>
          ))}
        </div>

        <div className="flex items-center justify-between border-b border-zinc-900 pb-4">
          <h2 className="text-2xl font-bold flex items-center gap-2">
            <LayoutGridIcon className="w-6 h-6 text-indigo-500" />
            {category ? <span className="capitalize">{category}</span> : "All Games"}
          </h2>
          <div className="text-sm text-zinc-500">
            {data?.total || 0} Games found
          </div>
        </div>

        {isLoading ? (
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-4 animate-pulse">
            {[...Array(12)].map((_, i) => (
              <div key={i} className="aspect-[4/3] bg-zinc-900 rounded-xl" />
            ))}
          </div>
        ) : (
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-4">
            {data?.games.map((game) => (
              <GameCard key={game.id} game={game} />
            ))}
          </div>
        )}
      </main>
    </div>
  );
}

function GameCard({ game }: { game: any }) {
  return (
    <Link 
      to={`/game/${game.slug}`}
      className="group relative aspect-[4/3] rounded-xl overflow-hidden bg-zinc-900 border border-zinc-800/50 hover:border-indigo-500/50 transition-all shadow-lg hover:shadow-indigo-500/10"
    >
      <img 
        src={game.thumbnail} 
        alt={game.title}
        className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-110 group-hover:blur-[2px]"
      />
      <div className="absolute inset-0 bg-gradient-to-t from-black/90 via-black/20 to-transparent opacity-0 group-hover:opacity-100 transition-opacity flex flex-col justify-end p-4">
        <h3 className="text-white font-bold text-sm truncate mb-2">{game.title}</h3>
        <div className="flex items-center justify-between">
          <span className="text-[10px] uppercase tracking-wider text-zinc-400 font-bold">{game.provider}</span>
          <div className="w-8 h-8 rounded-full bg-indigo-600 flex items-center justify-center shadow-lg shadow-indigo-600/50 transform translate-y-4 group-hover:translate-y-0 transition-transform">
            <Play className="w-4 h-4 text-white fill-current" />
          </div>
        </div>
      </div>
      {game.isHot && (
        <div className="absolute top-2 right-2 px-2 py-0.5 rounded-md bg-orange-500 text-[10px] font-bold text-white flex items-center gap-1">
          <Flame className="w-3 h-3" /> HOT
        </div>
      )}
      {game.isNew && (
        <div className="absolute top-2 right-2 px-2 py-0.5 rounded-md bg-green-500 text-[10px] font-bold text-white flex items-center gap-1">
          <Star className="w-3 h-3" /> NEW
        </div>
      )}
    </Link>
  );
}

function LayoutGridIcon(props: any) {
  return (
    <svg
      {...props}
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <rect width="7" height="7" x="3" y="3" rx="1" />
      <rect width="7" height="7" x="14" y="3" rx="1" />
      <rect width="7" height="7" x="14" y="14" rx="1" />
      <rect width="7" height="7" x="3" y="14" rx="1" />
    </svg>
  );
}
