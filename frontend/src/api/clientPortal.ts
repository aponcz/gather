import { apiFetch, uploadToPresignedUrl } from './client';
import { Contact, Loan, UploadedFile } from '../types';

export function requestMagicLink(email: string) {
  return apiFetch<{ magic_token: string }>('/api/v1/client/magic-link', {
    method: 'POST',
    auth: false,
    body: JSON.stringify({ email })
  });
}

export function createClientSession(magic_token: string) {
  return apiFetch<{ token: string; contact: Contact }>('/api/v1/client/sessions', {
    method: 'POST',
    auth: false,
    body: JSON.stringify({ magic_token })
  });
}

export function getClientLoan(publicToken: string) {
  return apiFetch<Loan>(`/api/v1/client/loans/${publicToken}`, { auth: 'client' });
}

export async function uploadRequestItem(requestItemId: number, file: File) {
  const presign = await apiFetch<{ upload_url: string; storage_key: string }>(`/api/v1/client/request-items/${requestItemId}/upload-url`, {
    method: 'POST',
    auth: 'client',
    body: JSON.stringify({ filename: file.name, content_type: file.type || 'application/octet-stream' })
  });

  await uploadToPresignedUrl(presign.upload_url, file);

  return apiFetch<UploadedFile>(`/api/v1/client/request-items/${requestItemId}/complete-upload`, {
    method: 'POST',
    auth: 'client',
    body: JSON.stringify({
      storage_key: presign.storage_key,
      filename: file.name,
      content_type: file.type || 'application/octet-stream',
      byte_size: file.size
    })
  });
}

export function getUploadedFileDownloadUrl(id: number) {
  return apiFetch<{ url: string }>(`/api/v1/client/uploaded-files/${id}/download_url`, { auth: 'client' });
}
