import { useState } from 'react';
import { Navigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export function Login() {
  const { user } = useAuth();
  const [error, setError] = useState<string | null>(null);

  if (user) return <Navigate to="/" replace />;

  async function signInWithProText() {
    setError(null);
    try {
      const result = await import('../api/admin').then((api) => api.getProTextAuthorizationUrl());
      window.location.assign(result.authorization_url);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'OAuth sign-in failed');
    }
  }

  return (
    <div className="auth-page">
      <div className="card auth-card">
        <h1>Sign in</h1>
        <p className="muted">Manage document collection loans, reviews, and secure client uploads.</p>
        {error && <div className="error">{error}</div>}
        <button className="primary" type="button" onClick={() => void signInWithProText()}>
          Sign in with ProText
        </button>
      </div>
    </div>
  );
}
