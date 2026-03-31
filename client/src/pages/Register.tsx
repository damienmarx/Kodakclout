import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { UserPlus, Mail, Lock, User, ArrowRight, ShieldCheck, Loader2, Chrome } from "lucide-react";
import { trpc } from "../lib/trpc";
import { APP_NAME, API_PREFIX } from "@kodakclout/shared";

export default function Register() {
  const navigate = useNavigate();
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");

  const registerMutation = trpc.auth.register.useMutation({
    onSuccess: () => {
      navigate("/login", { state: { message: "Registration successful! Please login." } });
    },
    onError: (err) => {
      setError(err.message);
    },
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    registerMutation.mutate({ name, email, password });
  };

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
            <h1 className="text-3xl font-extrabold tracking-tight text-white">Create Account</h1>
            <p className="text-zinc-400">Join the premium gaming community.</p>
          </div>
        </div>

        <div className="bg-zinc-900/50 border border-zinc-800/50 p-8 rounded-3xl shadow-2xl backdrop-blur-xl space-y-6">
          <form onSubmit={handleSubmit} className="space-y-4">
            {error && (
              <div className="p-3 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm font-medium">
                {error}
              </div>
            )}
            
            <div className="space-y-2">
              <label className="text-xs font-bold text-zinc-500 uppercase tracking-widest ml-1">Full Name</label>
              <div className="relative group">
                <User className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-zinc-500 group-focus-within:text-indigo-400 transition-colors" />
                <input 
                  type="text" 
                  required
                  placeholder="John Doe"
                  className="w-full bg-zinc-950 border border-zinc-800 rounded-2xl py-4 pl-12 pr-4 text-white focus:outline-none focus:ring-2 focus:ring-indigo-500/20 focus:border-indigo-500/50 transition-all"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                />
              </div>
            </div>

            <div className="space-y-2">
              <label className="text-xs font-bold text-zinc-500 uppercase tracking-widest ml-1">Email Address</label>
              <div className="relative group">
                <Mail className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-zinc-500 group-focus-within:text-indigo-400 transition-colors" />
                <input 
                  type="email" 
                  required
                  placeholder="name@example.com"
                  className="w-full bg-zinc-950 border border-zinc-800 rounded-2xl py-4 pl-12 pr-4 text-white focus:outline-none focus:ring-2 focus:ring-indigo-500/20 focus:border-indigo-500/50 transition-all"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                />
              </div>
            </div>

            <div className="space-y-2">
              <label className="text-xs font-bold text-zinc-500 uppercase tracking-widest ml-1">Password</label>
              <div className="relative group">
                <Lock className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-zinc-500 group-focus-within:text-indigo-400 transition-colors" />
                <input 
                  type="password" 
                  required
                  placeholder="••••••••"
                  className="w-full bg-zinc-950 border border-zinc-800 rounded-2xl py-4 pl-12 pr-4 text-white focus:outline-none focus:ring-2 focus:ring-indigo-500/20 focus:border-indigo-500/50 transition-all"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                />
              </div>
            </div>

            <button 
              type="submit"
              disabled={registerMutation.isLoading}
              className="w-full flex items-center justify-center gap-3 py-4 bg-indigo-600 text-white font-bold rounded-2xl transition-all hover:bg-indigo-500 active:scale-95 group disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {registerMutation.isLoading ? <Loader2 className="w-5 h-5 animate-spin" /> : <UserPlus className="w-5 h-5" />}
              Create Account
              {!registerMutation.isLoading && <ArrowRight className="w-4 h-4 ml-2 opacity-0 group-hover:opacity-100 group-hover:translate-x-1 transition-all" />}
            </button>
          </form>

          <div className="relative">
            <div className="absolute inset-0 flex items-center">
              <span className="w-full border-t border-zinc-800"></span>
            </div>
            <div className="relative flex justify-center text-xs uppercase">
              <span className="bg-zinc-900 px-4 text-zinc-500 font-bold">Or continue with</span>
            </div>
          </div>

          <div className="space-y-4">
            <button 
              onClick={handleGoogleLogin}
              className="w-full flex items-center justify-center gap-3 py-4 bg-white text-black font-bold rounded-2xl transition-all hover:bg-zinc-200 active:scale-95 group"
            >
              <Chrome className="w-5 h-5" />
              Google OAuth
            </button>
          </div>

          <div className="relative">
            <div className="absolute inset-0 flex items-center">
              <span className="w-full border-t border-zinc-800"></span>
            </div>
            <div className="relative flex justify-center text-xs uppercase">
              <span className="bg-zinc-900 px-4 text-zinc-500 font-bold">Secure Registration</span>
            </div>
          </div>

          <div className="flex items-start gap-4 p-4 rounded-2xl bg-indigo-500/5 border border-indigo-500/10">
            <ShieldCheck className="w-6 h-6 text-indigo-400 shrink-0 mt-0.5" />
            <div className="space-y-1">
              <p className="text-sm font-bold text-indigo-100">Encrypted Storage</p>
              <p className="text-xs text-indigo-400/80 leading-relaxed">
                Passwords are salted and hashed using industry-standard bcrypt before being stored.
              </p>
            </div>
          </div>
        </div>

        <p className="text-center text-zinc-500 text-sm">
          Already have an account? <Link to="/login" className="text-indigo-400 font-bold hover:underline">Sign in</Link>
        </p>
      </div>
    </div>
  );
}
