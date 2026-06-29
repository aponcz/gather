import { FormEvent, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { clientTokenKey, setToken } from '../lib/storage';
import * as clientApi from '../api/clientPortal';

export function ClientPortal() {
  const navigate = useNavigate();
  const [email, setEmail] = useState('jane@example.com');
  const [magicToken, setMagicToken] = useState('');
  const [error, setError] = useState<string | null>(null);

  async function requestLink(event: FormEvent) {
    event.preventDefault();
    setError(null);
    try {
      const result = await clientApi.requestMagicLink(email);
      setMagicToken(result.magic_token);
    } catch (err) { setError(err instanceof Error ? err.message : 'Could not request link'); }
  }

  async function startSession() {
    setError(null);
    try {
      const result = await clientApi.createClientSession(magicToken);
      setToken(clientTokenKey, result.token);
      alert('Client session saved. Open the invite link from the admin detail page.');
      navigate('/client');
    } catch (err) { setError(err instanceof Error ? err.message : 'Invalid magic token'); }
  }

  return <section className="client-page">
    <div className="card auth-card">
      <h1>Client portal sign in</h1>
      <p className="muted">For local development, the backend returns the magic token directly instead of emailing it.</p>
      <form onSubmit={requestLink} className="form-stack">
        <label>Email<input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required /></label>
        <button className="primary">Request magic link</button>
      </form>
      {magicToken && <div className="token-box">
        <label>Magic token<textarea value={magicToken} onChange={(e) => setMagicToken(e.target.value)} /></label>
        <button className="secondary" onClick={startSession}>Create client session</button>
      </div>}
      {error && <div className="error">{error}</div>}
    </div>
  </section>;
}
