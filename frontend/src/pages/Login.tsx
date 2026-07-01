import { FormEvent, useState } from 'react';
import { Link, Navigate, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { ApiError } from '../api/client';

export function Login() {
  const { user, signIn, signUp } = useAuth();
  const navigate = useNavigate();
  const [mode, setMode] = useState<'login' | 'register'>('login');
  const [form, setForm] = useState({
    company_name: 'Acme Lending',
    name: 'Admin User',
    email: 'admin@acme.test',
    password: 'password123',
    phone_number: '',
    address_line_1: '',
    address_line_2: '',
    city: '',
    state: '',
    zip_code: '',
    website: '',
    subdomain: ''
  });
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
      if (err instanceof ApiError && err.body && typeof err.body === 'object') {
        const body = err.body as { details?: string[]; error?: string };
        if (body.details && body.details.length > 0) {
          setError(body.details.join(', '));
          return;
        }
      }
      setError(err instanceof Error ? err.message : 'Authentication failed');
    }
  }

  return (
    <div className="auth-page">
      <form className="card auth-card" onSubmit={submit}>
        <h1>{mode === 'login' ? 'Sign in' : 'Create your workspace'}</h1>
        <p className="muted">Manage document collection invites, reviews, and secure client uploads.</p>
        {mode === 'register' && <>
          <label>Company<input value={form.company_name} onChange={(e) => setForm({ ...form, company_name: e.target.value })} /></label>
          <label>Name<input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} /></label>
          <label>Phone number<input value={form.phone_number} onChange={(e) => setForm({ ...form, phone_number: e.target.value })} /></label>
          <label>Address line 1<input value={form.address_line_1} onChange={(e) => setForm({ ...form, address_line_1: e.target.value })} /></label>
          <label>Address line 2<input value={form.address_line_2} onChange={(e) => setForm({ ...form, address_line_2: e.target.value })} /></label>
          <label>City<input value={form.city} onChange={(e) => setForm({ ...form, city: e.target.value })} /></label>
          <label>State<input value={form.state} onChange={(e) => setForm({ ...form, state: e.target.value })} /></label>
          <label>Zip code<input value={form.zip_code} onChange={(e) => setForm({ ...form, zip_code: e.target.value })} /></label>
          <label>Website<input value={form.website} onChange={(e) => setForm({ ...form, website: e.target.value })} /></label>
          <label>Subdomain<input value={form.subdomain} onChange={(e) => setForm({ ...form, subdomain: e.target.value })} /></label>
        </>}
        <label>Email<input type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} /></label>
        <label>Password<input type="password" value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} /></label>
        {mode === 'login' && (
          <div style={{ textAlign: 'right', marginTop: '-10px', marginBottom: '15px' }}>
            <Link to="/forgot-password" style={{ fontSize: '0.9em', textDecoration: 'none', color: '#0066cc' }}>
              Forgot password?
            </Link>
          </div>
        )}
        {error && <div className="error">{error}</div>}
        <button className="primary" type="submit">{mode === 'login' ? 'Sign in' : 'Register'}</button>
        <button type="button" className="link-button" onClick={() => setMode(mode === 'login' ? 'register' : 'login')}>
          {mode === 'login' ? 'Need an account? Register' : 'Already have an account? Sign in'}
        </button>
      </form>
    </div>
  );
}
