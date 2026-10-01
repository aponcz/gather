import { useState } from 'react';
import { Link, NavLink, Outlet, useNavigate } from 'react-router-dom';
import { Building2, ContactRound, FileCheck2, Files, LayoutDashboard, LogOut, Plus, Repeat2, ShieldCheck } from 'lucide-react';
import { useAuth } from '../context/AuthContext';

export function Layout() {
  const { user, company, companies, switchCompany, signOut } = useAuth();
  const navigate = useNavigate();
  const [switchingCompany, setSwitchingCompany] = useState(false);
  const canAccessAdminDashboard = ['admin', 'god'].includes(user?.role || '');

  async function handleCompanyChange(nextCompanyId: string) {
    if (!nextCompanyId || nextCompanyId === company?.id) return;
    setSwitchingCompany(true);
    try {
      await switchCompany(nextCompanyId);
    } finally {
      setSwitchingCompany(false);
    }
  }

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <Link to="/loans" className="sidebar-brand">
          <span className="sidebar-brand-mark"><FileCheck2 size={21} /></span>
          <span>ProText <strong>Gather</strong></span>
        </Link>

        {user && (
          <div className="sidebar-workspace">
            <span className="sidebar-label">Workspace</span>
            {companies.length > 1 ? <div className="sidebar-company-select"><Building2 size={16} />
            <select
              value={company?.id ?? ''}
              onChange={(event) => void handleCompanyChange(event.target.value)}
              disabled={switchingCompany}
              aria-label="Active company"
            >
              {companies.map((availableCompany) => (
                <option key={availableCompany.id} value={availableCompany.id}>
                  {availableCompany.name}
                </option>
              ))}
            </select>
            </div> : <div className="sidebar-company-name"><Building2 size={16} /><strong>{company?.name || 'Company workspace'}</strong></div>}
            {switchingCompany && <p className="sidebar-switching">Switching company…</p>}
          </div>
        )}

        <nav className="sidebar-nav">
          <span className="sidebar-label">Manage</span>
          <NavLink to="/loans" end><Files size={17} /><span>Loans</span></NavLink>
          <NavLink to="/loans/new"><Plus size={17} /><span>New loan</span></NavLink>
          <NavLink to="/contacts"><ContactRound size={17} /><span>Contacts</span></NavLink>
          <NavLink to="/company"><Building2 size={17} /><span>Company</span></NavLink>
          {!import.meta.env.PROD && <NavLink to="/client"><ShieldCheck size={17} /><span>Client portal</span></NavLink>}
          {user && companies.length > 1 && <NavLink to="/switch-company"><Repeat2 size={17} /><span>Switch company</span></NavLink>}
          {canAccessAdminDashboard && <><span className="sidebar-label sidebar-admin-label">Administration</span><NavLink to="/admin"><LayoutDashboard size={17} /><span>Admin dashboard</span></NavLink></>}
        </nav>

        {user && <div className="sidebar-account">
          <div className="sidebar-avatar">{user.name?.charAt(0).toUpperCase() || user.email.charAt(0).toUpperCase()}</div>
          <div className="sidebar-user"><strong>{user.name || 'ProText user'}</strong><span>{user.email}</span></div>
          <button type="button" onClick={() => { signOut(); navigate('/login'); }} aria-label="Sign out" title="Sign out"><LogOut size={16} /></button>
        </div>}
      </aside>
      <main className="content">
        <Outlet />
      </main>
    </div>
  );
}
