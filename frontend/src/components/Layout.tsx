import { useState } from 'react';
import { Link, NavLink, Outlet, useNavigate } from 'react-router-dom';
import { FileCheck2, LogOut, Repeat2 } from 'lucide-react';
import { useAuth } from '../context/AuthContext';

export function Layout() {
  const { user, company, companies, switchCompany, signOut } = useAuth();
  const navigate = useNavigate();
  const [switchingCompany, setSwitchingCompany] = useState(false);
  const [switchError, setSwitchError] = useState<string | null>(null);
  const canAccessAdminDashboard = ['admin', 'god'].includes(user?.role || '');
  const [signOutError, setSignOutError] = useState<string | null>(null);

  async function handleSignOut() {
    setSignOutError(null);
    try {
      await signOut();
      navigate('/login');
    } catch {
      setSignOutError('Unable to sign out. Please try again.');
    }
  }

  async function handleCompanyChange(nextCompanyId: string) {
    if (!nextCompanyId || nextCompanyId === company?.id) return;
    setSwitchingCompany(true);
    setSwitchError(null);
    try {
      const redirecting = await switchCompany(nextCompanyId);
      if (!redirecting) navigate('/');
    } catch (error) {
      setSwitchError(error instanceof Error ? error.message : 'Failed to switch company');
    } finally {
      setSwitchingCompany(false);
    }
  }

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <Link to="/" className="brand"><FileCheck2 size={24} /> ProText Gather</Link>
        {user && companies.length > 1 && (
          <div style={{ marginBottom: '12px' }}>
            <label style={{ display: 'block', fontSize: '0.8rem', marginBottom: '6px' }}>Active company</label>
            <select
              value={company?.id ?? ''}
              onChange={(event) => void handleCompanyChange(event.target.value)}
              disabled={switchingCompany}
              style={{ width: '100%' }}
            >
              {companies.map((availableCompany) => (
                <option key={availableCompany.id} value={availableCompany.id}>
                  {availableCompany.name}
                </option>
              ))}
            </select>
            {switchingCompany && (
              <p className="muted" style={{ marginTop: '6px' }}>
                Switching company…
              </p>
            )}
            {switchError && <p role="alert" className="error">{switchError}</p>}
          </div>
        )}
        <nav>
          <NavLink to="/" end>Dashboard</NavLink>
          {canAccessAdminDashboard && <NavLink to="/admin">Admin Dashboard</NavLink>}
          <NavLink to="/loans/new">New Loan</NavLink>
          <NavLink to="/contacts">Contacts</NavLink>
          <NavLink to="/company">Manage Company</NavLink>
          <NavLink to="/client">Client Portal</NavLink>
          {user && companies.length > 1 && <NavLink to="/switch-company"><Repeat2 size={16} /> Switch Company</NavLink>}
        </nav>
        {user && <button className="ghost" onClick={() => void handleSignOut()}><LogOut size={16} /> Sign out</button>}
        {signOutError && <p role="alert" className="error">{signOutError}</p>}
      </aside>
      <main className="content">
        <Outlet />
      </main>
    </div>
  );
}
