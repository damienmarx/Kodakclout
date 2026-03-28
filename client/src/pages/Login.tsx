import { Link } from "react-router-dom";
import { Chrome, ShieldCheck, Mail, ArrowRight } from "lucide-react";
import { APP_NAME, API_PREFIX } from "@kodakclout/shared";

export default function Login() {
  const handleGoogleLogin = () => {
    window.location.href = `${import.meta.env.VITE_API_URL || ""}${API_PREFIX}/oauth/google`;
  };

  return (
    <div className="min-h-screen bg-zinc-950 flex flex-col items-center justify-center p-4 relative overflow-hidden">
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[400px] bg-indigo-500/10 blur-[120px] -z-10 rounded-full" />
      
      <div className="max-w-md w-full space-y-8 relative">
        <div className="text-center space-y-4">
          <Link to="/home" className="text-3xl font-bold tracking-tighter bg-gradient-to-r from-indigo-500 to-purple-500 bg-clip-text text-transparent">
            {APP_NAME}
          </Link>
          <div className="space-y-2">
            <h1 className="text-3xl font-extrabold tracking-tight text-white">Welcome Back</h1>
            <p className="text-zinc-400">Secure access to your premium gaming account.</p>
          </div>
        </div>

        <div className="bg-zinc-900/50 border border-zinc-800/50 p-8 rounded-3xl shadow-2xl backdrop-blur-xl space-y-6">
          <div className="space-y-4">
            <button 
              onClick={handleGoogleLogin}
              className="w-full flex items-center justify-center gap-3 py-4 bg-white text-black font-bold rounded-2xl transition-all hover:bg-zinc-200 active:scale-95 group"
            >
              <Chrome className="w-5 h-5" />
              Sign in with Google
              <ArrowRight className="w-4 h-4 ml-2 opacity-0 group-hover:opacity-100 group-hover:translate-x-1 transition-all" />
            </button>
            
            <button 
              className="w-full flex items-center justify-center gap-3 py-4 bg-zinc-800 text-white font-bold rounded-2xl transition-all hover:bg-zinc-700 active:scale-95 cursor-not-allowed opacity-50"
              disabled
            >
              <Mail className="w-5 h-5" />
              Sign in with Email
            </button>
          </div>

          <div className="relative">
            <div className="absolute inset-0 flex items-center">
              <span className="w-full border-t border-zinc-800"></span>
            </div>
            <div className="relative flex justify-center text-xs uppercase">
              <span className="bg-zinc-900 px-4 text-zinc-500 font-bold">Secure Environment</span>
            </div>
          </div>

          <div className="flex items-start gap-4 p-4 rounded-2xl bg-indigo-500/5 border border-indigo-500/10">
            <ShieldCheck className="w-6 h-6 text-indigo-400 shrink-0 mt-0.5" />
            <div className="space-y-1">
              <p className="text-sm font-bold text-indigo-100">Zero-Knowledge Auth</p>
              <p className="text-xs text-indigo-400/80 leading-relaxed">
                Your credentials are never stored on our servers. We use enterprise-grade OAuth for maximum security.
              </p>
            </div>
          </div>
        </div>

        <p className="text-center text-zinc-500 text-sm">
          Don't have an account? <span className="text-indigo-400 font-bold hover:underline cursor-pointer">Sign up now</span>
        </p>
      </div>
    </div>
  );
}
