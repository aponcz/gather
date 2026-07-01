import React, { createContext, useContext, useEffect, useMemo, useState } from 'react';
import { clearToken, setToken, adminTokenKey } from '../lib/storage';
import * as adminApi from '../api/admin';
import { Company, User } from '../types';

type AuthContextValue = {
  user: User | null;
  company: Company | null;
  companies: Company[];
  loading: boolean;
  signIn: (email: string, password: string) => Promise<void>;
  signUp: (payload: {
    company_name: string;
    name: string;
    email: string;
    password: string;
    phone_number?: string;
    address_line_1?: string;
    address_line_2?: string;
    city?: string;
    state?: string;
    zip_code?: string;
    website?: string;
    subdomain?: string;
    status?: number;
    logo?: string;
    trial_started_on?: string;
    activated_on?: string;
    delinquent_on?: string;
    suspended_on?: string;
  }) => Promise<void>;
  switchCompany: (companyId: string) => Promise<void>;
  signOut: () => void;
};

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [company, setCompany] = useState<Company | null>(null);
  const [companies, setCompanies] = useState<Company[]>([]);
  const [loading, setLoading] = useState(true);

  function applyAuthState(result: { user: User; company: Company; companies: Company[] }) {
    setUser(result.user);
    setCompany(result.company);
    setCompanies(result.companies || []);
  }

  useEffect(() => {
    adminApi.me()
      .then((result) => applyAuthState(result))
      .catch(() => {
        clearToken(adminTokenKey);
        setUser(null);
        setCompany(null);
        setCompanies([]);
      })
      .finally(() => setLoading(false));
  }, []);

  const value = useMemo<AuthContextValue>(() => ({
    user,
    company,
    companies,
    loading,
    async signIn(email, password) {
      const result = await adminApi.login(email, password);
      setToken(adminTokenKey, result.token);
      applyAuthState(result);
    },
    async signUp(payload) {
      const result = await adminApi.register(payload);
      setToken(adminTokenKey, result.token);
      applyAuthState(result);
    },
    async switchCompany(companyId) {
      const result = await adminApi.switchCompany(companyId);
      setToken(adminTokenKey, result.token);
      applyAuthState(result);
    },
    signOut() {
      clearToken(adminTokenKey);
      setUser(null);
      setCompany(null);
      setCompanies([]);
    }
  }), [user, company, companies, loading]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const value = useContext(AuthContext);
  if (!value) throw new Error('useAuth must be used inside AuthProvider');
  return value;
}
