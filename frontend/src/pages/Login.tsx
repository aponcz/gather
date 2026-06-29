import { FormEvent, useState } from 'react';
import { Navigate, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export function Login() {
  const { user, signIn, signUp } = useAuth();
  const navigate = useNavigate();
  const [mode, setMode] = useState<'login' | 'register'>('login');
  const [form, setForm] = useState({ organization_name: 'Acme Lending', name: 'Admin User', email: 'admin@acme.test', password: 'password123' });
  const [error, setError] = useState<string | null>(null);

  if (user) return <Navigate to="/" replace />;

  async function submit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    try {
      if (mode === 'login') await signIn(form.email, form.password);
      else await signUp(form);
      navigate('/');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Authentication failed');
    }
  }

  return (
    <div className="auth-page">
      <form className="card auth-card" onSubmit={submit}>
        <h1>{mode === 'login' ? 'Sign in' : 'Create your workspace'}</h1>
        <p className="muted">Manage document collection invites, reviews, and secure client uploads.</p>
        {mode === 'register' && <>
          <label>Organization<input value={form.organization_name} onChange={(e) => setForm({ ...form, organization_name: e.target.value })} /></label>
          <label>Name<input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} /></label>
        </>}
        <label>Email<input type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} /></label>
        <label>Password<input type="password" value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} /></label>
        {error && <div className="error">{error}</div>}
        <button className="primary" type="submit">{mode === 'login' ? 'Sign in' : 'Register'}</button>
        <button type="button" className="link-button" onClick={() => setMode(mode === 'login' ? 'register' : 'login')}>
          {mode === 'login' ? 'Need an account? Register' : 'Already have an account? Sign in'}
        </button>
      </form>
    </div>
  );
}
