import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

const Home: React.FC = () => {
  const { user } = useAuth();
  const [isFlipped, setIsFlipped] = useState(false);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const timer = setTimeout(() => setIsLoading(false), 1500);
    return () => clearTimeout(timer);
  }, []);

  if (isLoading) {
    return (
      <div className="fixed inset-0 bg-black flex items-center justify-center z-50">
        <div className="relative w-64 h-64">
          <div className="absolute inset-0 morph-shape"></div>
          <div className="absolute inset-0 flex items-center justify-center">
            <h1 className="text-2xl font-black tracking-tighter text-white animate-pulse">
              CLOUTSCAPE
            </h1>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#050505] text-white overflow-hidden relative flex items-center justify-center p-4">
      {/* Background Elements */}
      <div className="absolute top-[-10%] left-[-10%] w-[40%] h-[40%] morph-shape opacity-20"></div>
      <div className="absolute bottom-[-10%] right-[-10%] w-[40%] h-[40%] morph-shape opacity-20" style={{ background: 'linear-gradient(45deg, #00d4ff, #0055ff)' }}></div>

      <div className="w-full max-w-4xl perspective-1000 h-[600px]">
        <div className={`relative w-full h-full flip-card-inner preserve-3d ${isFlipped ? 'flipped' : ''}`}>
          
          {/* FRONT SIDE: Marketing/Entry */}
          <div className="absolute inset-0 backface-hidden glass-dark rounded-3xl p-8 flex flex-col items-center justify-center text-center border-white/10">
            <div className="mb-8">
              <h1 className="text-6xl md:text-8xl font-black tracking-tighter mb-2 bg-clip-text text-transparent bg-gradient-to-b from-white to-white/40">
                KODAKCLOUT
              </h1>
              <p className="text-blue-400 font-mono tracking-widest uppercase text-sm">The Sovereign Gaming Protocol</p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-12 w-full max-w-2xl">
              <div className="glass-card p-4 rounded-2xl">
                <h3 className="font-bold text-xl mb-1">350+</h3>
                <p className="text-xs text-white/50 uppercase">Elite Games</p>
              </div>
              <div className="glass-card p-4 rounded-2xl">
                <h3 className="font-bold text-xl mb-1">0.1s</h3>
                <p className="text-xs text-white/50 uppercase">Payout Speed</p>
              </div>
              <div className="glass-card p-4 rounded-2xl">
                <h3 className="font-bold text-xl mb-1">100%</h3>
                <p className="text-xs text-white/50 uppercase">Provably Fair</p>
              </div>
            </div>

            <button 
              onClick={() => setIsFlipped(true)}
              className="group relative px-12 py-4 bg-white text-black font-black rounded-full overflow-hidden transition-all hover:scale-105 active:scale-95"
            >
              <span className="relative z-10">ENTER CLOUTSCAPE</span>
              <div className="absolute inset-0 bg-gradient-to-r from-blue-500 to-purple-600 opacity-0 group-hover:opacity-100 transition-opacity"></div>
            </button>
          </div>

          {/* BACK SIDE: Quick Access / Dashboard */}
          <div className="absolute inset-0 backface-hidden rotate-y-180 glass-dark rounded-3xl p-8 flex flex-col border-white/10">
            <div className="flex justify-between items-center mb-12">
              <h2 className="text-2xl font-black tracking-tighter">DASHBOARD</h2>
              <button onClick={() => setIsFlipped(false)} className="text-white/40 hover:text-white transition-colors font-mono text-xs uppercase">
                ← Back to Intro
              </button>
            </div>

            <div className="flex-1 flex flex-col justify-center items-center">
              {user ? (
                <div className="text-center w-full max-w-md">
                  <div className="mb-8 p-8 glass-card rounded-3xl">
                    <p className="text-white/50 uppercase text-xs tracking-widest mb-2 font-mono">Current Balance</p>
                    <h3 className="text-5xl font-black text-green-400">${user.balance.toLocaleString()}</h3>
                  </div>
                  <div className="grid grid-cols-2 gap-4">
                    <Link to="/games" className="glass-card p-6 rounded-2xl hover:bg-white/10 transition-all text-center font-bold">
                      PLAY NOW
                    </Link>
                    <Link to="/games" className="glass-card p-6 rounded-2xl hover:bg-white/10 transition-all text-center font-bold">
                      DEPOSIT
                    </Link>
                  </div>
                </div>
              ) : (
                <div className="text-center">
                  <h3 className="text-3xl font-black mb-8">ACCESS RESTRICTED</h3>
                  <div className="flex gap-4 justify-center">
                    <Link to="/login" className="px-8 py-3 bg-white text-black font-bold rounded-full hover:scale-105 transition-transform">
                      LOGIN
                    </Link>
                    <Link to="/register" className="px-8 py-3 border border-white/20 font-bold rounded-full hover:bg-white/5 transition-colors">
                      REGISTER
                    </Link>
                  </div>
                </div>
              )}
            </div>

            <div className="mt-auto pt-8 border-t border-white/5 flex justify-between items-center text-[10px] font-mono text-white/30 uppercase tracking-widest">
              <span>System Status: Operational</span>
              <span>v1.0.4-Stable</span>
            </div>
          </div>

        </div>
      </div>
    </div>
  );
};

export default Home;
