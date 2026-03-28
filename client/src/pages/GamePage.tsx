import { useState, useEffect } from "react";
import { useParams, Link, useNavigate } from "react-router-dom";
import { ArrowLeft, Maximize2, RefreshCcw, ShieldAlert, Loader2 } from "lucide-react";
import { trpc } from "../lib/trpc";
import { APP_NAME } from "@kodakclout/shared";

export default function GamePage() {
  const { slug } = useParams<{ slug: string }>();
  const navigate = useNavigate();
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [isLaunching, setIsLaunching] = useState(true);
  const [launchUrl, setLaunchUrl] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const launchMutation = trpc.launchGame.useMutation({
    onSuccess: (data) => {
      setLaunchUrl(data.url);
      setIsLaunching(false);
    },
    onError: (err) => {
      setError(err.message || "Failed to launch game. Please sign in.");
      setIsLaunching(false);
    }
  });

  useEffect(() => {
    if (slug) {
      launchMutation.mutate({ slug });
    }
  }, [slug]);

  const toggleFullscreen = () => {
    const iframe = document.getElementById("game-iframe");
    if (iframe) {
      if (!isFullscreen) {
        if (iframe.requestFullscreen) iframe.requestFullscreen();
      } else {
        if (document.exitFullscreen) document.exitFullscreen();
      }
      setIsFullscreen(!isFullscreen);
    }
  };

  if (error) {
    return (
      <div className="min-h-screen bg-zinc-950 flex flex-col items-center justify-center p-4">
        <div className="max-w-md w-full bg-zinc-900 border border-zinc-800 p-8 rounded-2xl text-center space-y-6">
          <div className="w-16 h-16 bg-red-500/10 rounded-full flex items-center justify-center mx-auto">
            <ShieldAlert className="w-8 h-8 text-red-500" />
          </div>
          <div className="space-y-2">
            <h2 className="text-2xl font-bold text-white">Access Denied</h2>
            <p className="text-zinc-400">{error}</p>
          </div>
          <div className="flex flex-col gap-3">
            <Link to="/login" className="w-full py-3 bg-indigo-600 hover:bg-indigo-500 text-white font-bold rounded-xl transition-all">
              Sign In to Play
            </Link>
            <Link to="/games" className="w-full py-3 bg-zinc-800 hover:bg-zinc-700 text-white font-bold rounded-xl transition-all">
              Back to Lobby
            </Link>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-zinc-950 flex flex-col">
      <nav className="h-14 border-b border-zinc-900 bg-zinc-950 px-4 flex items-center justify-between shrink-0">
        <div className="flex items-center gap-4">
          <button 
            onClick={() => navigate("/games")}
            className="p-2 hover:bg-zinc-900 rounded-lg text-zinc-400 hover:text-white transition-all"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
          <span className="text-sm font-bold tracking-tight hidden sm:inline-block">{APP_NAME}</span>
          <span className="text-zinc-700 mx-2 hidden sm:inline-block">/</span>
          <span className="text-sm font-medium text-zinc-300 truncate max-w-[150px]">{slug}</span>
        </div>
        
        <div className="flex items-center gap-2">
          <button 
            onClick={() => window.location.reload()}
            className="p-2 hover:bg-zinc-900 rounded-lg text-zinc-400 hover:text-white transition-all"
            title="Reload Game"
          >
            <RefreshCcw className="w-4 h-4" />
          </button>
          <button 
            onClick={toggleFullscreen}
            className="p-2 hover:bg-zinc-900 rounded-lg text-zinc-400 hover:text-white transition-all"
            title="Fullscreen"
          >
            <Maximize2 className="w-4 h-4" />
          </button>
        </div>
      </nav>

      <main className="flex-1 bg-black relative">
        {isLaunching && (
          <div className="absolute inset-0 flex flex-col items-center justify-center gap-4 bg-zinc-950 z-10">
            <Loader2 className="w-10 h-10 text-indigo-500 animate-spin" />
            <div className="text-center space-y-1">
              <p className="text-white font-bold">Launching Game</p>
              <p className="text-xs text-zinc-500">Connecting to secure server...</p>
            </div>
          </div>
        )}
        
        {launchUrl && (
          <iframe 
            id="game-iframe"
            src={launchUrl}
            className="w-full h-full border-none"
            allowFullScreen
            allow="autoplay; encrypted-media; fullscreen"
          />
        )}
      </main>
    </div>
  );
}
