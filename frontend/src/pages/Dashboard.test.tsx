import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import * as adminApi from '../api/admin';
import { Dashboard } from './Dashboard';

vi.mock('../api/admin', () => ({
  listLoans: vi.fn(),
  importProTextLoans: vi.fn(),
}));

describe('Dashboard ProText import', () => {
  beforeEach(() => vi.clearAllMocks());

  it('imports loans on demand, reports the result, and refreshes the list', async () => {
    vi.mocked(adminApi.listLoans)
      .mockResolvedValueOnce([])
      .mockResolvedValueOnce([{ id: 42, title: 'Imported loan', status: 'draft', request_items: [] }]);
    vi.mocked(adminApi.importProTextLoans).mockResolvedValue({
      fetched_count: 2,
      created_count: 1,
      skipped_count: 1,
      loans: [{ id: 42, title: 'Imported loan' }],
    });

    render(<MemoryRouter><Dashboard /></MemoryRouter>);
    await screen.findByText('No loans yet');
    await userEvent.click(screen.getByRole('button', { name: 'Import from ProText' }));

    expect(await screen.findByText('Imported loan')).toBeInTheDocument();
    expect(screen.getByRole('status')).toHaveTextContent('1 created, 1 skipped from 2 fetched');
    expect(adminApi.importProTextLoans).toHaveBeenCalledTimes(1);
    await waitFor(() => expect(adminApi.listLoans).toHaveBeenCalledTimes(2));
  });
});
