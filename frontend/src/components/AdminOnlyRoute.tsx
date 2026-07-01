import { Navigate, Outlet } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export function AdminOnlyRoute() {
  const { user, loading } = useAuth();

  if (loading) return <div className="center-card">Loading…</div>;
  if (!user) return <Navigate to="/login" replace />;
  if (!['admin', 'god'].includes(user.role || '')) return <Navigate to="/" replace />;

  return <Outlet />;
}
