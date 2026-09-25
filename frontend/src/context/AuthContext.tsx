import React, { createContext, useContext, useEffect, useMemo, useRef, useState } from 'react';
import { clearToken, getToken, setToken, adminTokenKey } from '../lib/storage';
import * as adminApi from '../api/admin';
import { Company, User } from '../types';
import { companyUrl, navigateToCompany } from '../lib/companyUrl';
import { ApiError } from '../api/client';

type AuthContextValue = {
  user: User | null;
  company: Company | null;
  companies: Company[];
  loading: boolean;
  sessionError: string | null;
  completeOAuthSignIn: (token: string) => Promise<void>;
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
  switchCompany: (companyId: string) => Promise<boolean>;
  signOut: () => Promise<void>;
};

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [company, setCompany] = useState<Company | null>(null);
  const [companies, setCompanies] = useState<Company[]>([]);
  const [loading, setLoading] = useState(true);
  const [sessionError, setSessionError] = useState<string | null>(null);
  const initialization = useRef<Promise<Awaited<ReturnType<typeof adminApi.restoreBrowserSession>>> | null>(null);

  function applyAuthState(result: { user: User; company: Company; companies: Company[] }) {
    setSessionError(null);
    setUser(result.user);
    setCompany(result.company);
    setCompanies(result.companies || []);
  }

  useEffect(() => {
    if (!initialization.current) {
      const code = new URLSearchParams(window.location.hash.slice(1)).get('company_switch_code');
      if (code) {
        // Remove the single-use code before rendering the signed-in application.
        window.history.replaceState(null, '', window.location.pathname + window.location.search);
        initialization.current = adminApi.completeCompanySwitch(code).then((result) => {
          setToken(adminTokenKey, result.token);
          return adminApi.createBrowserSession();
        });
      } else {
        initialization.current = adminApi.restoreBrowserSession().catch((error) => {
          // Upgrade a pre-existing local session once, from its original origin.
          if (error instanceof ApiError && error.status === 401 &&
              (error.body as { error?: string } | null)?.error === 'missing_browser_session' && getToken(adminTokenKey)) {
            return adminApi.createBrowserSession();
          }
          throw error;
        });
      }
    }

    initialization.current
      .then((result) => {
        setToken(adminTokenKey, result.token);
        applyAuthState(result);
      })
      .catch((error) => {
        clearToken(adminTokenKey);
        setUser(null);
        setCompany(null);
        setCompanies([]);
        if (error instanceof ApiError && error.status === 403) {
          setSessionError('You do not have access to this company.');
        } else if (!(error instanceof ApiError && error.status === 401)) {
          setSessionError('Unable to restore your session. Please reload to try again.');
        }
      })
      .finally(() => setLoading(false));
  }, []);

  const value = useMemo<AuthContextValue>(() => ({
    user,
    company,
    companies,
    loading,
    sessionError,
    async completeOAuthSignIn(token) {
      setToken(adminTokenKey, token);
      const result = await adminApi.createBrowserSession();
      setToken(adminTokenKey, result.token);
      applyAuthState(result);
    },
    async signIn(email, password) {
      const result = await adminApi.login(email, password);
      setToken(adminTokenKey, result.token);
      const session = await adminApi.createBrowserSession();
      setToken(adminTokenKey, session.token);
      applyAuthState(session);
    },
    async signUp(payload) {
      const result = await adminApi.register(payload);
      setToken(adminTokenKey, result.token);
      const session = await adminApi.createBrowserSession();
      setToken(adminTokenKey, session.token);
      applyAuthState(session);
    },
    async switchCompany(companyId) {
      const selectedCompany = companies.find((candidate) => candidate.id === companyId);
      if (!selectedCompany) throw new Error('Company not found.');
      const target = companyUrl(selectedCompany.subdomain, window.location.href, import.meta.env.VITE_COMPANY_BASE_DOMAIN);
      if (target.origin !== window.location.origin) {
        const { code } = await adminApi.createCompanySwitchCode(companyId);
        target.hash = new URLSearchParams({ company_switch_code: code }).toString();
        navigateToCompany(target);
        return true;
      }
      const result = await adminApi.switchCompany(companyId);
      setToken(adminTokenKey, result.token);
      applyAuthState(result);
      return false;
    },
    async signOut() {
      await adminApi.destroyBrowserSession();
      clearToken(adminTokenKey);
      setUser(null);
      setCompany(null);
      setCompanies([]);
      setSessionError(null);
    }
  }), [user, company, companies, loading, sessionError]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const value = useContext(AuthContext);
  if (!value) throw new Error('useAuth must be used inside AuthProvider');
  return value;
}
