import { Link, NavLink, Outlet, useNavigate } from 'react-router-dom';
import { FileCheck2, LogOut } from 'lucide-react';
import { useAuth } from '../context/AuthContext';

export function Layout() {
  const { user, signOut } = useAuth();
  const navigate = useNavigate();

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <Link to="/" className="brand"><FileCheck2 size={24} /> ProText Gather</Link>
        <nav>
          <NavLink to="/" end>Dashboard</NavLink>
          <NavLink to="/invites/new">New Invite</NavLink>
          <NavLink to="/contacts">Contacts</NavLink>
          <NavLink to="/client">Client Portal</NavLink>
        </nav>
        {user && <button className="ghost" onClick={() => { signOut(); navigate('/login'); }}><LogOut size={16} /> Sign out</button>}
      </aside>
      <main className="content">
        <Outlet />
      </main>
    </div>
  );
}
