import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import * as adminApi from '../api/admin';
import { Invite } from '../types';
import { StatusBadge } from '../components/StatusBadge';

export function Dashboard() {
  const [invites, setInvites] = useState<Invite[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    adminApi.listInvites().then(setInvites).catch((err) => setError(err.message));
  }, []);

  return (
    <section>
      <div className="page-header">
        <div><h1>Document collection</h1><p className="muted">Track active invites and client progress.</p></div>
        <Link className="primary button" to="/invites/new">Create invite</Link>
      </div>
      {error && <div className="error">{error}</div>}
      <div className="stats-grid">
        <div className="card"><strong>{invites.length}</strong><span>Total invites</span></div>
        <div className="card"><strong>{invites.filter(i => ['sent','viewed'].includes(i.status)).length}</strong><span>In progress</span></div>
        <div className="card"><strong>{invites.filter(i => i.status === 'completed').length}</strong><span>Completed</span></div>
      </div>
      <div className="card table-card">
        <table>
          <thead><tr><th>Title</th><th>Client</th><th>Status</th><th>Due</th></tr></thead>
          <tbody>{invites.map((invite) => (
            <tr key={invite.id}>
              <td><Link to={`/invites/${invite.id}`}>{invite.title}</Link></td>
              <td>{invite.contact?.name ?? '—'}</td>
              <td><StatusBadge status={invite.status} /></td>
              <td>{invite.due_at ? new Date(invite.due_at).toLocaleDateString() : '—'}</td>
            </tr>
          ))}</tbody>
        </table>
      </div>
    </section>
  );
}
