import { apiFetch } from './client';
import { Contact, Invite, UploadedFile, User } from '../types';

export function login(email: string, password: string) {
  return apiFetch<{ token: string; user: User }>('/api/v1/auth/login', {
    method: 'POST',
    auth: false,
    body: JSON.stringify({ email, password })
  });
}

export function register(payload: { organization_name: string; name: string; email: string; password: string }) {
  return apiFetch<{ token: string; user: User }>('/api/v1/auth/register', {
    method: 'POST',
    auth: false,
    body: JSON.stringify(payload)
  });
}

export function me() {
  return apiFetch<{ user: User }>('/api/v1/me');
}

export function listContacts() {
  return apiFetch<Contact[]>('/api/v1/contacts');
}

export function createContact(payload: { name: string; email: string; phone?: string }) {
  return apiFetch<Contact>('/api/v1/contacts', { method: 'POST', body: JSON.stringify(payload) });
}

export function listInvites() {
  return apiFetch<Invite[]>('/api/v1/invites');
}

export function getInvite(id: string | number) {
  return apiFetch<Invite>(`/api/v1/invites/${id}`);
}

export function createInvite(payload: {
  contact_id: string;
  title: string;
  message?: string;
  due_at?: string;
  request_items: Array<{ title: string; description?: string; kind: string; required: boolean }>;
}) {
  return apiFetch<Invite>('/api/v1/invites', { method: 'POST', body: JSON.stringify(payload) });
}

export function sendInvite(id: number) {
  return apiFetch<{ status: string; invite: Invite }>(`/api/v1/invites/${id}/send_invite`, { method: 'POST' });
}

export function cancelInvite(id: number) {
  return apiFetch<Invite>(`/api/v1/invites/${id}/cancel`, { method: 'POST' });
}

export function approveFile(id: number) {
  return apiFetch<UploadedFile>(`/api/v1/uploaded_files/${id}/approve`, { method: 'POST' });
}

export function rejectFile(id: number, reason: string) {
  return apiFetch<UploadedFile>(`/api/v1/uploaded_files/${id}/reject`, { method: 'POST', body: JSON.stringify({ reason }) });
}

export function getDownloadUrl(id: number) {
  return apiFetch<{ url: string }>(`/api/v1/uploaded_files/${id}/download_url`);
}
