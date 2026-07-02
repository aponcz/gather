import { Link } from 'react-router-dom';

export function AdminDashboard() {
  return (
    <section className="form-stack" style={{ maxWidth: 760 }}>
      <h1>Admin Dashboard</h1>
      <p className="muted">Manage users and companies.</p>

      <div className="card form-stack">
        <h2>Users</h2>
        <p className="muted">Invite users, review members, and update access roles.</p>
        <Link className="primary" to="/admin/users">Manage Users</Link>
      </div>

      <div className="card form-stack">
        <h2>Companies</h2>
        <p className="muted">Edit company settings and switch active company.</p>
        <Link className="primary" to="/admin/companies">Manage Companies</Link>
      </div>
    </section>
  );
}
