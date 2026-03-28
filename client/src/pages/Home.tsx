import { Link } from "react-router-dom";
import { Play, Shield, Zap, LayoutGrid } from "lucide-react";
import { APP_NAME } from "@kodakclout/shared";
import { useAuth } from "../context/AuthContext";

export default function Home() {
  const { user, logout } = useAuth();

  return (
    <div className="flex flex-col min-h-screen">
      <nav className="border-b border-zinc-800/50 bg-zinc-950/50 backdrop-blur-xl sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-4 h-16 flex items-center justify-between">
          <Link to="/home" className="text-xl font-bold tracking-tighter bg-gradient-to-r from-indigo-500 to-purple-500 bg-clip-text text-transparent">
            {APP_NAME}
          </Link>
          <div className="flex gap-4 items-center">
            <Link to="/games" className="text-sm font-medium text-zinc-400 hover:text-white transition-colors">Games</Link>
            {user ? (
              <div className="flex items-center gap-4">
                <span className="text-sm text-zinc-400">Hi, <span className="text-white font-bold">{user.name}</span></span>
                <button 
                  onClick={logout}
                  className="px-4 py-2 bg-zinc-800 hover:bg-zinc-700 text-white text-sm font-medium rounded-lg transition-all"
                >
                  Sign Out
                </button>
              </div>
            ) : (
              <Link to="/login" className="px-4 py-2 bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-medium rounded-lg transition-all shadow-lg shadow-indigo-500/20">Sign In</Link>
            )}
          </div>
        </div>
      </nav>

      <main className="flex-1 flex flex-col items-center justify-center px-4 py-24 relative overflow-hidden">
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[400px] bg-indigo-500/10 blur-[120px] -z-10 rounded-full" />
        
        <div className="max-w-3xl text-center space-y-8">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-indigo-500/10 border border-indigo-500/20 text-indigo-400 text-xs font-semibold uppercase tracking-wider">
            Premium Casino Experience
          </div>
          <h1 className="text-6xl md:text-7xl font-extrabold tracking-tight text-white">
            Elevate Your <span className="bg-gradient-to-r from-indigo-400 to-purple-400 bg-clip-text text-transparent">Gaming</span> Journey.
          </h1>
          <p className="text-lg text-zinc-400 max-w-xl mx-auto leading-relaxed">
            Experience the next generation of online gaming with {APP_NAME}. 
            Secure, fast, and built for players who demand the best.
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center pt-4">
            <Link to="/games" className="group px-8 py-4 bg-white text-black font-bold rounded-xl flex items-center justify-center gap-2 transition-all hover:scale-105 active:scale-95">
              <Play className="w-5 h-5 fill-current" />
              Play Now
            </Link>
            <button className="px-8 py-4 bg-zinc-900 border border-zinc-800 text-white font-bold rounded-xl hover:bg-zinc-800 transition-all">
              Learn More
            </button>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 max-w-5xl w-full mt-32">
          <FeatureCard 
            icon={<Shield className="w-6 h-6 text-indigo-400" />}
            title="Secure Platform"
            description="Built with enterprise-grade security to keep your data and funds safe."
          />
          <FeatureCard 
            icon={<Zap className="w-6 h-6 text-purple-400" />}
            title="Instant Access"
            description="Launch your favorite games instantly with zero lag or waiting time."
          />
          <FeatureCard 
            icon={<LayoutGrid className="w-6 h-6 text-pink-400" />}
            title="Massive Library"
            description="Hundreds of premium slots and table games from top providers."
          />
        </div>
      </main>

      <footer className="border-t border-zinc-900 py-12 px-4">
        <div className="max-w-7xl mx-auto flex flex-col md:flex-row justify-between items-center gap-8">
          <div className="text-zinc-500 text-sm">
            © 2026 {APP_NAME}. Owned by Damien.
          </div>
          <div className="flex gap-8 text-zinc-400 text-sm">
            <a href="#" className="hover:text-white transition-colors">Terms</a>
            <a href="#" className="hover:text-white transition-colors">Privacy</a>
            <a href="#" className="hover:text-white transition-colors">Support</a>
          </div>
        </div>
      </footer>
    </div>
  );
}

function FeatureCard({ icon, title, description }: { icon: React.ReactNode, title: string, description: string }) {
  return (
    <div className="p-8 rounded-2xl bg-zinc-900/50 border border-zinc-800/50 hover:border-zinc-700/50 transition-all group">
      <div className="w-12 h-12 rounded-xl bg-zinc-800 flex items-center justify-center mb-6 group-hover:scale-110 transition-transform">
        {icon}
      </div>
      <h3 className="text-xl font-bold text-white mb-2">{title}</h3>
      <p className="text-zinc-400 leading-relaxed">{description}</p>
    </div>
  );
}
