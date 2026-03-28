import { createContext, useContext, ReactNode } from "react";
import { trpc } from "../lib/trpc";
import { Session } from "@kodakclout/shared";

interface AuthContextType {
  user: Session | null;
  isLoading: boolean;
  logout: () => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const { data: user, isLoading, refetch } = trpc.me.useQuery();
  const logoutMutation = trpc.auth.logout.useMutation({
    onSuccess: () => {
      refetch();
      window.location.href = "/login";
    },
  });

  const logout = () => {
    logoutMutation.mutate();
  };

  // Convert string date to Date object if needed
  const session: Session | null = user ? {
    ...user,
    expiresAt: new Date(user.expiresAt)
  } : null;

  return (
    <AuthContext.Provider value={{ user: session, isLoading, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
}
