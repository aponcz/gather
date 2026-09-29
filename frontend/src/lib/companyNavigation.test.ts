import { describe, expect, it } from 'vitest';
import { companySwitchUrl } from './companyNavigation';

describe('companySwitchUrl', () => {
  it.each([
    ['https://old.example.com/loans/12?tab=files', undefined, 'https://new.example.com'],
    ['https://example.com/', undefined, 'https://new.example.com'],
    ['http://localhost:5173/', undefined, 'http://new.localhost:5173'],
    ['http://old.localhost:5173/', undefined, 'http://new.localhost:5173'],
    ['https://custom.example.org/', 'gather.example.co.uk', 'https://new.gather.example.co.uk'],
  ])('switches from %s while carrying the session in the fragment', (current, base, origin) => {
    const url = new URL(companySwitchUrl(current, 'new', 'session-token', base)!);
    expect(url.origin).toBe(origin);
    expect(url.pathname).toBe('/login/oauth-callback');
    expect(url.search).toBe('');
    expect(new URLSearchParams(url.hash.slice(1)).get('token')).toBe('session-token');
  });

  it('avoids redirects for missing subdomains or the current host', () => {
    expect(companySwitchUrl('https://new.example.com/', null, 'token')).toBeNull();
    expect(companySwitchUrl('https://new.example.com/', 'new', 'token')).toBeNull();
  });

  it('rejects subdomains that could change the destination domain', () => {
    expect(() => companySwitchUrl('https://old.example.com/', 'evil.org/', 'token')).toThrow('invalid subdomain');
  });
});
