import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import * as adminApi from '../api/admin';
import { Contacts } from './Contacts';

vi.mock('../api/admin', () => ({
  listContacts: vi.fn(),
  createContact: vi.fn(),
  updateContact: vi.fn(),
  deleteContact: vi.fn(),
}));

const contact = { id: 'contact-1', name: 'Jane Client', email: 'jane@example.test', phone: '555-0100' };

describe('Contacts', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(adminApi.listContacts).mockResolvedValue([contact]);
  });

  it('edits a contact', async () => {
    vi.mocked(adminApi.updateContact).mockResolvedValue({ ...contact, name: 'Jane Updated' });
    const user = userEvent.setup();
    render(<Contacts />);

    await user.click(await screen.findByRole('button', { name: 'Edit Jane Client' }));
    const name = screen.getByLabelText(/Name/);
    await user.clear(name);
    await user.type(name, 'Jane Updated');
    await user.click(screen.getByRole('button', { name: 'Save changes' }));

    expect(adminApi.updateContact).toHaveBeenCalledWith('contact-1', {
      name: 'Jane Updated', email: 'jane@example.test', phone: '555-0100'
    });
  });

  it('soft deletes a contact after confirmation', async () => {
    vi.spyOn(window, 'confirm').mockReturnValue(true);
    vi.mocked(adminApi.deleteContact).mockResolvedValue(undefined);
    const user = userEvent.setup();
    render(<Contacts />);

    await user.click(await screen.findByRole('button', { name: 'Delete Jane Client' }));

    expect(window.confirm).toHaveBeenCalled();
    expect(adminApi.deleteContact).toHaveBeenCalledWith('contact-1');
  });
});
