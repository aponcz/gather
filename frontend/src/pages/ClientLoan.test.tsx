import { render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import * as clientApi from '../api/clientPortal';
import { clientTokenKey, setToken } from '../lib/storage';
import { ClientLoan } from './ClientLoan';

vi.mock('../api/clientPortal', () => ({
  createClientSession: vi.fn(),
  getClientLoan: vi.fn(),
  uploadRequestItem: vi.fn(),
  getUploadedFileDownloadUrl: vi.fn(),
}));

vi.mock('../lib/storage', () => ({
  clientTokenKey: 'gather_client_token',
  setToken: vi.fn(),
}));

describe('ClientLoan email link', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('exchanges the query-string magic token before loading the loan', async () => {
    vi.mocked(clientApi.createClientSession).mockResolvedValue({
      token: 'client-session-token',
      contact: { id: 1, name: 'Client', email: 'client@example.test' },
    });
    vi.mocked(clientApi.getClientLoan).mockResolvedValue({
      id: 42,
      title: 'Document request',
      status: 'sent',
      request_items: [],
    });

    render(
      <MemoryRouter initialEntries={['/client/loans/public-token?magic_token=emailed-token']}>
        <Routes>
          <Route path="/client/loans/:publicToken" element={<ClientLoan />} />
        </Routes>
      </MemoryRouter>,
    );

    expect(await screen.findByRole('heading', { name: 'Document request' })).toBeInTheDocument();
    expect(clientApi.createClientSession).toHaveBeenCalledWith('emailed-token');
    expect(clientApi.getClientLoan).toHaveBeenCalledWith('public-token');
    expect(setToken).toHaveBeenCalledWith(clientTokenKey, 'client-session-token');
    expect(vi.mocked(clientApi.createClientSession).mock.invocationCallOrder[0])
      .toBeLessThan(vi.mocked(clientApi.getClientLoan).mock.invocationCallOrder[0]);
    await waitFor(() => expect(window.location.search).toBe(''));
  });
});
