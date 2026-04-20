import { Component, ErrorInfo, ReactNode } from "react";

interface Props {
  children: ReactNode;
}

interface State {
  hasError: boolean;
}

class ErrorBoundary extends Component<Props, State> {
  public state: State = {
    hasError: false
  };

  public static getDerivedStateFromError(_: Error): State {
    return { hasError: true };
  }

  public componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error("Uncaught error:", error, errorInfo);
  }

  public render() {
    if (this.state.hasError) {
      return (
        <div className="min-h-screen bg-black flex items-center justify-center p-4 text-center">
          <div className="glass-dark p-12 rounded-3xl max-w-md border-white/10">
            <h2 className="text-3xl font-black mb-4 tracking-tighter">SYSTEM ANOMALY</h2>
            <p className="text-white/60 mb-8 font-mono text-sm">
              The Cloutscape protocol encountered an unexpected state. Our autonomous framework is self-healing.
            </p>
            <button
              onClick={() => window.location.reload()}
              className="px-8 py-3 bg-white text-black font-bold rounded-full hover:scale-105 transition-transform"
            >
              REBOOT SESSION
            </button>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}

export default ErrorBoundary;
