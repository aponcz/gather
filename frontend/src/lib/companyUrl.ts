export function navigateToCompany(target: URL): void {
  window.location.assign(target.href);
}

export function companyUrl(subdomain: string | null | undefined, currentUrl: string, baseDomain?: string): URL {
  const current = new URL(currentUrl);
  const target = new URL('/', current);
  if (!subdomain) return target;
  if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(subdomain)) {
    throw new Error('This company has an invalid subdomain.');
  }

  const local = current.hostname === 'localhost' || current.hostname.endsWith('.localhost');
  const base = baseDomain || (local ? 'localhost' : undefined);
  if (!base || !/^[a-z0-9]+(?:[.-][a-z0-9]+)*$/.test(base)) {
    throw new Error('The company base domain has not been configured.');
  }
  target.hostname = `${subdomain}.${base}`;
  if (base !== 'localhost') target.protocol = 'https:';
  return target;
}
