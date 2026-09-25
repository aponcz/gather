import { StrictMode, type ReactNode } from 'react';
import { act, cleanup, renderHook, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { AuthProvider, useAuth } from './AuthContext';
import * as api from '../api/admin';
import { navigateToCompany } from '../lib/companyUrl';
import { adminTokenKey } from '../lib/storage';
import { ApiError } from '../api/client';

vi.mock('../api/admin', () => ({
  me: vi.fn(), switchCompany: vi.fn(), createCompanySwitchCode: vi.fn(), completeCompanySwitch: vi.fn(),
  createBrowserSession: vi.fn(), restoreBrowserSession: vi.fn(), destroyBrowserSession: vi.fn(), login: vi.fn()
}));
vi.mock('../lib/companyUrl', async (importOriginal) => ({
  ...await importOriginal<typeof import('../lib/companyUrl')>(), navigateToCompany: vi.fn()
}));

const original = { id: 'original', name: 'Original', subdomain: 'original' };
const destination = { id: 'destination', name: 'Destination', subdomain: 'acme' };
const session = {
  user: { id: 1, name: 'User', email: 'user@example.com', role: 'admin', company_id: 1 },
  company: original,
  companies: [original, destination]
} as Awaited<ReturnType<typeof api.me>>;
const wrapper = ({ children }: { children: ReactNode }) => <StrictMode><AuthProvider>{children}</AuthProvider></StrictMode>;

beforeEach(() => {
  vi.resetAllMocks();
  vi.stubEnv('VITE_COMPANY_BASE_DOMAIN', 'gather.stage.goprotext.com');
  window.localStorage.clear();
  window.history.replaceState(null, '', '/');
  vi.mocked(api.me).mockResolvedValue(session);
  vi.mocked(api.restoreBrowserSession).mockRejectedValue(new ApiError('No session', 401, { error: 'missing_browser_session' }));
  vi.mocked(api.createBrowserSession).mockResolvedValue({ ...session, token: 'original-token' });
  vi.mocked(api.destroyBrowserSession).mockResolvedValue(undefined);
});
afterEach(() => { cleanup(); vi.unstubAllEnvs(); });

describe('company switch authentication', () => {
  it('keeps same-origin switching working for companies without subdomains', async () => {
    const noSubdomain = { ...destination, subdomain: null };
    window.localStorage.setItem(adminTokenKey, 'original-token');
    vi.mocked(api.createBrowserSession).mockResolvedValue({ ...session, token: 'original-token', companies: [original, noSubdomain] });
    vi.mocked(api.switchCompany).mockResolvedValue({ ...session, company: noSubdomain, token: 'switched-token' });
    const { result } = renderHook(useAuth, { wrapper });
    await waitFor(() => expect(result.current.loading).toBe(false));
    await act(async () => { expect(await result.current.switchCompany(destination.id)).toBe(false); });
    expect(result.current.company?.id).toBe(destination.id);
    expect(window.localStorage.getItem(adminTokenKey)).toBe('switched-token');
    expect(api.createCompanySwitchCode).not.toHaveBeenCalled();
    expect(navigateToCompany).not.toHaveBeenCalled();
  });

  it('redirects to the selected subdomain using a one-time code', async () => {
    window.localStorage.setItem(adminTokenKey, 'original-token');
    vi.mocked(api.createCompanySwitchCode).mockResolvedValue({ code: 'one-time-code' });
    const { result } = renderHook(useAuth, { wrapper });
    await waitFor(() => expect(result.current.loading).toBe(false));
    await act(async () => { expect(await result.current.switchCompany(destination.id)).toBe(true); });
    expect(api.createCompanySwitchCode).toHaveBeenCalledWith(destination.id);
    const target = vi.mocked(navigateToCompany).mock.calls[0][0];
    expect(target.hostname).toBe('acme.gather.stage.goprotext.com');
    expect(target.pathname).toBe('/');
    expect(target.hash).toBe('#company_switch_code=one-time-code');
    expect(window.localStorage.getItem(adminTokenKey)).toBe('original-token');
  });

  it('consumes a handoff once under StrictMode and replaces a stale destination session', async () => {
    window.localStorage.setItem(adminTokenKey, 'stale-token');
    window.history.replaceState(null, '', '/#company_switch_code=one-time-code');
    vi.mocked(api.completeCompanySwitch).mockResolvedValue({ ...session, company: destination, token: 'new-token' });
    vi.mocked(api.createBrowserSession).mockResolvedValue({ ...session, company: destination, token: 'new-token' });
    const { result } = renderHook(useAuth, { wrapper });
    await waitFor(() => expect(result.current.loading).toBe(false));
    expect(api.completeCompanySwitch).toHaveBeenCalledExactlyOnceWith('one-time-code');
    expect(api.me).not.toHaveBeenCalled();
    expect(window.location.hash).toBe('');
    expect(result.current.company?.id).toBe(destination.id);
    expect(window.localStorage.getItem(adminTokenKey)).toBe('new-token');
  });

  it('keeps the original session when issuing the code fails', async () => {
    window.localStorage.setItem(adminTokenKey, 'original-token');
    vi.mocked(api.createCompanySwitchCode).mockRejectedValue(new Error('Network error'));
    const { result } = renderHook(useAuth, { wrapper });
    await waitFor(() => expect(result.current.loading).toBe(false));
    await expect(result.current.switchCompany(destination.id)).rejects.toThrow('Network error');
    expect(navigateToCompany).not.toHaveBeenCalled();
    expect(result.current.company?.id).toBe(original.id);
  });

  it('clears stale credentials if the handoff has expired', async () => {
    window.localStorage.setItem(adminTokenKey, 'stale-token');
    window.history.replaceState(null, '', '/#company_switch_code=expired');
    vi.mocked(api.completeCompanySwitch).mockRejectedValue(new Error('Expired'));
    const { result } = renderHook(useAuth, { wrapper });
    await waitFor(() => expect(result.current.loading).toBe(false));
    expect(window.localStorage.getItem(adminTokenKey)).toBeNull();
    expect(result.current.user).toBeNull();
    expect(window.location.hash).toBe('');
  });
});

describe('opening a company hostname directly', () => {
  it('restores the hostname-scoped session without any local token or handoff code', async () => {
    vi.mocked(api.restoreBrowserSession).mockResolvedValue({ ...session, company: destination, token: 'destination-token' });
    const { result } = renderHook(useAuth, { wrapper });
    expect(result.current.loading).toBe(true);
    await waitFor(() => expect(result.current.loading).toBe(false));
    expect(api.restoreBrowserSession).toHaveBeenCalledTimes(1);
    expect(api.createBrowserSession).not.toHaveBeenCalled();
    expect(result.current.company?.id).toBe(destination.id);
    expect(window.localStorage.getItem(adminTokenKey)).toBe('destination-token');
  });

  it('uses the shared session even if this origin holds an older local token', async () => {
    window.localStorage.setItem(adminTokenKey, 'stale-token');
    vi.mocked(api.restoreBrowserSession).mockResolvedValue({ ...session, company: destination, token: 'destination-token' });
    const { result } = renderHook(useAuth, { wrapper });
    await waitFor(() => expect(result.current.loading).toBe(false));
    expect(api.createBrowserSession).not.toHaveBeenCalled();
    expect(result.current.company?.id).toBe(destination.id);
  });

  it('upgrades a legacy local token to a browser session once', async () => {
    window.localStorage.setItem(adminTokenKey, 'original-token');
    const { result } = renderHook(useAuth, { wrapper });
    await waitFor(() => expect(result.current.loading).toBe(false));
    expect(api.createBrowserSession).toHaveBeenCalledTimes(1);
    expect(result.current.company?.id).toBe(original.id);
  });

  it('shows access denied and does not fall back to a stale token for another company', async () => {
    window.localStorage.setItem(adminTokenKey, 'stale-token');
    vi.mocked(api.restoreBrowserSession).mockRejectedValue(new ApiError('Denied', 403, { error: 'company_access_denied' }));
    const { result } = renderHook(useAuth, { wrapper });
    await waitFor(() => expect(result.current.loading).toBe(false));
    expect(result.current.sessionError).toBe('You do not have access to this company.');
    expect(result.current.user).toBeNull();
    expect(api.createBrowserSession).not.toHaveBeenCalled();
    expect(window.localStorage.getItem(adminTokenKey)).toBeNull();
  });

  it('shows the login page only when no session exists', async () => {
    const { result } = renderHook(useAuth, { wrapper });
    await waitFor(() => expect(result.current.loading).toBe(false));
    expect(result.current.user).toBeNull();
    expect(result.current.sessionError).toBeNull();
    expect(api.createBrowserSession).not.toHaveBeenCalled();
  });

  it('establishes a shared session after password sign-in', async () => {
    vi.mocked(api.login).mockResolvedValue({ ...session, token: 'login-token' });
    vi.mocked(api.createBrowserSession).mockResolvedValue({ ...session, company: destination, token: 'destination-token' });
    const { result } = renderHook(useAuth, { wrapper });
    await waitFor(() => expect(result.current.loading).toBe(false));
    await act(async () => result.current.signIn('user@example.com', 'password'));
    expect(api.createBrowserSession).toHaveBeenCalledTimes(1);
    expect(result.current.company?.id).toBe(destination.id);
    expect(window.localStorage.getItem(adminTokenKey)).toBe('destination-token');
  });

  it('removes the backend session on sign-out', async () => {
    vi.mocked(api.restoreBrowserSession).mockResolvedValue({ ...session, token: 'token' });
    const { result } = renderHook(useAuth, { wrapper });
    await waitFor(() => expect(result.current.loading).toBe(false));
    await act(async () => result.current.signOut());
    expect(api.destroyBrowserSession).toHaveBeenCalledTimes(1);
    expect(window.localStorage.getItem(adminTokenKey)).toBeNull();
    expect(result.current.user).toBeNull();
  });
});
