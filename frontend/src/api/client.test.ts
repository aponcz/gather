import { afterEach, describe, expect, it, vi } from 'vitest';
import { apiFetch } from './client';

vi.mock('../lib/storage', () => ({
  adminTokenKey: 'admin-token',
  clientTokenKey: 'client-token',
  getToken: vi.fn(() => null),
}));

describe('apiFetch errors', () => {
  afterEach(() => vi.unstubAllGlobals());

  it('uses backend details as the user-facing message', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response(JSON.stringify({
      error: 'protext_sync_failed',
      details: 'Company does not have API access',
    }), { status: 502, headers: { 'Content-Type': 'application/json' } })));

    await expect(apiFetch('/api/v1/loans/import_loans', { method: 'POST' }))
      .rejects.toThrow('Company does not have API access');
  });
});
