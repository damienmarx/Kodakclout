export interface User {
  id: number;
  email: string;
  name: string;
  avatar?: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface Session {
  userId: number;
  email: string;
  name: string;
  avatar?: string;
  balance?: number;
  expiresAt: Date;
}

export interface OAuthProfile {
  id: string;
  email: string;
  name: string;
  picture?: string;
  provider: "google";
}
