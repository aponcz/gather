export function companySwitchUrl(
  currentUrl: string,
  subdomain: string | null | undefined,
  token: string,
  baseDomain = import.meta.env.VITE_APP_BASE_DOMAIN as string | undefined,
): string | null {
  const label = subdomain?.trim().toLowerCase();
  if (!label) return null;
  if (!/^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/.test(label)) {
    throw new Error('The selected company has an invalid subdomain');
  }

  const url = new URL(currentUrl);
  const hostname = url.hostname;
  let domain = baseDomain?.trim().toLowerCase();
  if (!domain) {
    if (hostname === 'localhost' || hostname.endsWith('.localhost')) {
      domain = 'localhost';
    } else if (hostname.includes(':') || /^\d+(?:\.\d+){3}$/.test(hostname)) {
      throw new Error('Set VITE_APP_BASE_DOMAIN to switch company subdomains from an IP address');
    } else {
      const parts = hostname.split('.');
      domain = parts.length > 2 ? parts.slice(1).join('.') : hostname;
    }
  }
  url.hostname = `${label}.${domain}`;
  if (url.hostname === hostname) return null;
  url.pathname = '/login/oauth-callback';
  url.search = '';
  // Fragments stay in the browser and are not sent to the web server.
  url.hash = new URLSearchParams({ token }).toString();
  return url.toString();
}
