import { describe, expect, it } from 'vitest';
import { companyUrl } from './companyUrl';

describe('companyUrl', () => {
  it.each(['https://gather.stage.goprotext.com', 'https://old.gather.stage.goprotext.com/loans/123?tab=files'])('navigates from %s to the selected company dashboard', (current) => {
    expect(companyUrl('acme', current, 'gather.stage.goprotext.com').href).toBe('https://acme.gather.stage.goprotext.com/');
  });

  it('preserves the local development port', () => {
    expect(companyUrl('acme', 'http://old.localhost:5173/company').href).toBe('http://acme.localhost:5173/');
  });

  it('keeps companies without a subdomain on the current origin', () => {
    expect(companyUrl(null, 'https://gather.stage.goprotext.com/company').href).toBe('https://gather.stage.goprotext.com/');
  });

  it('rejects invalid subdomains and missing deployment configuration', () => {
    expect(() => companyUrl('attacker.example', 'https://gather.stage.goprotext.com', 'gather.stage.goprotext.com')).toThrow();
    expect(() => companyUrl('acme', 'https://unknown.example')).toThrow();
  });
});
