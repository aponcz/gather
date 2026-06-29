import React, { createContext, useContext, useEffect, useMemo, useState } from 'react';
import { clearToken, setToken, adminTokenKey } from '../lib/storage';
import * as adminApi from '../api/admin';
import { User } from '../types';

type AuthContextValue = {
  user: User | null;
  loading: boolean;
  signIn: (email: string, password: string) => Promise<void>;
  signUp: (payload: { organization_name: string; name: string; email: string; password: string }) => Promise<void>;
  signOut: () => void;
};

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    adminApi.me()
      .then((result) => setUser(result.user))
      .catch(() => clearToken(adminTokenKey))
      .finally(() => setLoading(false));
  }, []);

  const value = useMemo<AuthContextValue>(() => ({
    user,
    loading,
    async signIn(email, password) {
      const result = await adminApi.login(email, password);
      setToken(adminTokenKey, result.token);
      setUser(result.user);
    },
    async signUp(payload) {
      const result = await adminApi.register(payload);
      setToken(adminTokenKey, result.token);
      setUser(result.user);
    },
    signOut() {
      clearToken(adminTokenKey);
      setUser(null);
    }
  }), [user, loading]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const value = useContext(AuthContext);
  if (!value) throw new Error('useAuth must be used inside AuthProvider');
  return value;
}
