import { Link } from "react-router-dom";
import { Play, Shield, Zap, LayoutGrid } from "lucide-react";
import { APP_NAME } from "@kodakclout/shared";
import { useAuth } from "../context/AuthContext";

export default function Home() {
  const { user, logout } = useAuth();

  return (
    <div className="flex flex-col min-h-screen bg-gradient-to-b from-slate-950 via-red-950 to-slate-950 relative overflow-hidden">
      {/* Obsidian texture overlay */}
      <div className="fixed inset-0 opacity-30 pointer-events-none mix-blend-multiply" style={{
        backgroundImage: `repeating-linear-gradient(
          45deg,
          transparent,
          transparent 2px,
          rgba(0, 0, 0, 0.1) 2px,
          rgba(0, 0, 0, 0.1) 4px
        )`
      }} />

      <nav className="border-b border-red-900/50 bg-slate-950/70 backdrop-blur-xl sticky top-0 z-50 relative">
        <div className="max-w-7xl mx-auto px-4 h-16 flex items-center justify-between">
          <Link to="/home" className="text-2xl font-black tracking-tighter bg-gradient-to-r from-red-600 via-red-500 to-red-700 bg-clip-text text-transparent" style={{ fontFamily: "'Orbitron', 'Space Mono', monospace" }}>
            {APP_NAME}
          </Link>
          <div className="flex gap-4 items-center">
            <Link to="/games" className="text-sm font-semibold text-red-200/70 hover:text-red-300 transition-colors">Games</Link>
            {user ? (
              <div className="flex items-center gap-6">
                <div className="flex flex-col items-end">
                  <span className="text-xs text-red-200/40 uppercase tracking-widest font-black">Balance</span>
                  <span className="text-sm font-black text-red-400">${(user.balance || 0).toLocaleString()}</span>
                </div>
                <div className="h-8 w-px bg-red-900/30" />
                <div className="flex items-center gap-4">
                  <span className="text-sm text-red-200/60">Hi, <span className="text-red-300 font-bold">{user.name}</span></span>
                  <button 
                    onClick={logout}
                    className="px-4 py-2 bg-red-900/40 hover:bg-red-900/60 text-red-200 text-sm font-semibold rounded-lg transition-all border border-red-700/50"
                  >
                    Sign Out
                  </button>
                </div>
              </div>
            ) : (
              <Link to="/login" className="px-4 py-2 bg-gradient-to-r from-red-600 to-red-700 hover:from-red-500 hover:to-red-600 text-white text-sm font-bold rounded-lg transition-all shadow-lg shadow-red-600/40">Sign In</Link>
            )}
          </div>
        </div>
      </nav>

      <main className="flex-1 flex flex-col items-center justify-center px-4 py-24 relative z-10">
        {/* Animated gradient orbs */}
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[400px] bg-red-600/15 blur-[120px] -z-10 rounded-full animate-pulse" />
        <div className="absolute bottom-1/3 right-0 w-[600px] h-[300px] bg-red-700/10 blur-[100px] -z-10 rounded-full" />
        
        <div className="max-w-4xl text-center space-y-8">
          <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-red-900/30 border border-red-700/50 text-red-300 text-xs font-black uppercase tracking-widest" style={{ fontFamily: "'Space Mono', monospace" }}>
            ⚡ Exclusive Private Community
          </div>
          
          <h1 className="text-7xl md:text-8xl font-black tracking-tighter text-white leading-tight" style={{ fontFamily: "'Orbitron', 'Space Mono', monospace" }}>
            Degens<span className="bg-gradient-to-r from-red-500 via-red-600 to-red-700 bg-clip-text text-transparent">Den</span>
          </h1>
          
          <p className="text-xl text-red-200/70 max-w-2xl mx-auto leading-relaxed font-light">
            The most exclusive gambling platform for 350 elite players. 340 premium games, zero compromises. 
            Built for those who demand the absolute best.
          </p>
          
          <div className="flex flex-col sm:flex-row gap-4 justify-center pt-6">
            <Link to="/games" className="group px-10 py-4 bg-gradient-to-r from-red-600 to-red-700 hover:from-red-500 hover:to-red-600 text-white font-black rounded-xl flex items-center justify-center gap-2 transition-all hover:scale-105 active:scale-95 shadow-lg shadow-red-600/50 uppercase tracking-wider text-sm">
              <Play className="w-5 h-5 fill-current" />
              Enter the Den
            </Link>
            <button className="px-10 py-4 bg-slate-900/60 border border-red-700/40 text-red-200 font-black rounded-xl hover:bg-slate-900/80 hover:border-red-600/60 transition-all uppercase tracking-wider text-sm">
              Learn More
            </button>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 max-w-5xl w-full mt-32">
          <FeatureCard 
            icon={<Shield className="w-6 h-6 text-red-400" />}
            title="Fortress Security"
            description="Military-grade encryption protects every transaction and your identity."
          />
          <FeatureCard 
            icon={<Zap className="w-6 h-6 text-red-500" />}
            title="Lightning Fast"
            description="340 games load instantly. Zero lag. Pure adrenaline."
          />
          <FeatureCard 
            icon={<LayoutGrid className="w-6 h-6 text-red-600" />}
            title="Elite Selection"
            description="Curated premium slots and games from the world's top providers."
          />
        </div>
      </main>

      <footer className="border-t border-red-900/40 py-12 px-4 relative z-10 bg-slate-950/50">
        <div className="max-w-7xl mx-auto flex flex-col md:flex-row justify-between items-center gap-8">
          <div className="text-red-200/50 text-sm font-medium">
            © 2026 DegensDen. Owned by Damien. For 350 Elite Players Only.
          </div>
          <div className="flex gap-8 text-red-200/60 text-sm font-medium">
            <a href="#" className="hover:text-red-300 transition-colors">Terms</a>
            <a href="#" className="hover:text-red-300 transition-colors">Privacy</a>
            <a href="#" className="hover:text-red-300 transition-colors">Support</a>
          </div>
        </div>
      </footer>
    </div>
  );
}

function FeatureCard({ icon, title, description }: { icon: React.ReactNode, title: string, description: string }) {
  return (
    <div className="p-8 rounded-2xl bg-red-950/30 border border-red-800/40 hover:border-red-700/60 transition-all group backdrop-blur-sm">
      <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-red-900 to-red-950 flex items-center justify-center mb-6 group-hover:scale-110 transition-transform shadow-lg shadow-red-600/20">
        {icon}
      </div>
      <h3 className="text-xl font-black text-red-100 mb-2 uppercase tracking-wide">{title}</h3>
      <p className="text-red-200/60 leading-relaxed font-light">{description}</p>
    </div>
  );
}
