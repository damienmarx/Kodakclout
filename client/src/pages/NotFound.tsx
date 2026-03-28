import { Link } from "react-router-dom";
import { MoveLeft, HelpCircle } from "lucide-react";
import { APP_NAME } from "@kodakclout/shared";

export default function NotFound() {
  return (
    <div className="min-h-screen bg-zinc-950 flex flex-col items-center justify-center p-4">
      <div className="max-w-md w-full text-center space-y-8">
        <div className="w-24 h-24 bg-indigo-500/10 rounded-full flex items-center justify-center mx-auto relative group">
          <HelpCircle className="w-12 h-12 text-indigo-500 group-hover:scale-110 transition-transform" />
          <div className="absolute inset-0 bg-indigo-500/20 blur-xl rounded-full -z-10 animate-pulse" />
        </div>
        
        <div className="space-y-4">
          <h1 className="text-6xl font-extrabold tracking-tighter text-white">404</h1>
          <h2 className="text-2xl font-bold text-zinc-300">Page Not Found</h2>
          <p className="text-zinc-500 leading-relaxed">
            The page you're looking for doesn't exist or has been moved to a different URL.
          </p>
        </div>

        <div className="flex flex-col gap-3 pt-4">
          <Link to="/home" className="w-full flex items-center justify-center gap-3 py-4 bg-white text-black font-bold rounded-2xl transition-all hover:bg-zinc-200 active:scale-95 group">
            <MoveLeft className="w-5 h-5 group-hover:-translate-x-1 transition-transform" />
            Back to Home
          </Link>
          <p className="text-xs text-zinc-600 uppercase font-bold tracking-widest">
            {APP_NAME} Error Reporting
          </p>
        </div>
      </div>
    </div>
  );
}
