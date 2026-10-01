import { adminTokenKey, clientTokenKey, getToken } from '../lib/storage';

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:3000';

type ApiOptions = RequestInit & { auth?: 'admin' | 'client' | false };

export class ApiError extends Error {
  status: number;
  body: unknown;

  constructor(message: string, status: number, body: unknown) {
    super(message);
    this.status = status;
    this.body = body;
  }
}

export async function apiFetch<T>(path: string, options: ApiOptions = {}): Promise<T> {
  const headers = new Headers(options.headers);
  if (!(options.body instanceof FormData) && !headers.has('Content-Type')) {
    headers.set('Content-Type', 'application/json');
  }

  const auth = options.auth ?? 'admin';
  const token = auth === 'admin' ? getToken(adminTokenKey) : auth === 'client' ? getToken(clientTokenKey) : null;
  if (token) headers.set('Authorization', `Bearer ${token}`);

  const response = await fetch(`${API_BASE_URL}${path}`, { ...options, headers });
  const text = await response.text();
  const body = text ? JSON.parse(text) : null;

  if (!response.ok) {
    const message = typeof body?.details === 'string' ? body.details : body?.error || response.statusText;
    throw new ApiError(message, response.status, body);
  }

  return body as T;
}

export async function apiFetchBlob(path: string, options: ApiOptions = {}): Promise<{ blob: Blob; filename?: string }> {
  const headers = new Headers(options.headers);
  if (!(options.body instanceof FormData) && !headers.has('Content-Type')) {
    headers.set('Content-Type', 'application/json');
  }

  const auth = options.auth ?? 'admin';
  const token = auth === 'admin' ? getToken(adminTokenKey) : auth === 'client' ? getToken(clientTokenKey) : null;
  if (token) headers.set('Authorization', `Bearer ${token}`);

  const response = await fetch(`${API_BASE_URL}${path}`, { ...options, headers });

  if (!response.ok) {
    const text = await response.text();
    const body = text ? JSON.parse(text) : null;
    const message = typeof body?.details === 'string' ? body.details : body?.error || response.statusText;
    throw new ApiError(message, response.status, body);
  }

  const blob = await response.blob();
  const contentDisposition = response.headers.get('content-disposition') || '';
  const match = contentDisposition.match(/filename="?([^";]+)"?/i);
  return { blob, filename: match?.[1] };
}

export async function uploadToPresignedUrl(url: string, file: File): Promise<void> {
  const response = await fetch(url, {
    method: 'PUT',
    headers: { 'Content-Type': file.type || 'application/octet-stream' },
    body: file
  });
  if (!response.ok) {
    const responseBody = await response.text();
    const s3Code = responseBody.match(/<Code>([^<]+)<\/Code>/)?.[1];
    const s3Message = responseBody.match(/<Message>([^<]+)<\/Message>/)?.[1];
    const details = [s3Code, s3Message].filter(Boolean).join(': ');
    throw new Error(`Upload failed (${response.status})${details ? `: ${details}` : ''}`);
  }
}
