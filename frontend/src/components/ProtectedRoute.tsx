import { Link, Navigate, Outlet } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export function ProtectedRoute() {
  const { user, loading, sessionError } = useAuth();
  if (loading) return <div className="center-card">Loading…</div>;
  if (sessionError) return <div className="center-card"><p role="alert">{sessionError}</p><Link to="/login">Sign in</Link></div>;
  return user ? <Outlet /> : <Navigate to="/login" replace />;
}
