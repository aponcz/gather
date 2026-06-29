export const adminTokenKey = 'gather_admin_token';
export const clientTokenKey = 'gather_client_token';

export function getToken(key: string): string | null {
  return window.localStorage.getItem(key);
}

export function setToken(key: string, token: string): void {
  window.localStorage.setItem(key, token);
}

export function clearToken(key: string): void {
  window.localStorage.removeItem(key);
}
