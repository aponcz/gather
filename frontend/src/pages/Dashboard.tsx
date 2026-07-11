import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import * as adminApi from '../api/admin';
import { Loan } from '../types';
import { StatusBadge } from '../components/StatusBadge';

function formatCurrencyFromCents(value?: number | null) {
  if (value === null || value === undefined) return '—';
  const amount = value / 100;

  return new Intl.NumberFormat(undefined, { style: 'currency', currency: 'USD', maximumFractionDigits: 2 }).format(amount);
}

export function Dashboard() {
  const [loans, setLoans] = useState<Loan[]>([]);
  const [error, setError] = useState<string | null>(null);

  function getPercentComplete(loan: Loan) {
    const totalRequestedDocuments = loan.request_items?.length || 0;
    const uploadedDocuments = (loan.request_items || []).filter((item) => (item.uploaded_files || []).length > 0).length;
    if (totalRequestedDocuments === 0) return 0;
    return Math.round((uploadedDocuments / totalRequestedDocuments) * 100);
  }

  useEffect(() => {
    adminApi.listLoans().then(setLoans).catch((err) => setError(err.message));
  }, []);

  return (
    <section>
      <div className="page-header">
        <div><h1>Document collection</h1><p className="muted">Track active loans and client progress.</p></div>
        <Link className="primary button" to="/loans/new">Create loan</Link>
      </div>
      {error && <div className="error">{error}</div>}
      <div className="stats-grid">
        <div className="card"><strong>{loans.length}</strong><span>Total loans</span></div>
        <div className="card"><strong>{loans.filter(i => ['sent','viewed'].includes(i.status)).length}</strong><span>In progress</span></div>
        <div className="card"><strong>{loans.filter(i => i.status === 'completed').length}</strong><span>Completed</span></div>
      </div>
      <div className="card table-card">
        <table>
          <thead><tr><th>Title</th><th>Client</th><th>Loan amount</th><th>Loan type</th><th>Status</th><th>Complete</th><th>Created</th><th>Due</th></tr></thead>
          <tbody>
            {loans.length === 0 ? (
              <tr>
                <td colSpan={8} className="muted">No loans yet.</td>
              </tr>
            ) : (
              loans.map((loan) => (
                <tr key={loan.id}>
                  <td><Link to={`/loans/${loan.id}`}>{loan.title}</Link></td>
                  <td>{loan.contact?.name ?? '—'}</td>
                  <td>{formatCurrencyFromCents(loan.loan_amount_in_cents)}</td>
                  <td>{loan.loan_type || '—'}</td>
                  <td><StatusBadge status={loan.status} /></td>
                  <td>{getPercentComplete(loan)}%</td>
                  <td>{loan.created_at ? new Date(loan.created_at).toLocaleDateString() : '—'}</td>
                  <td>{loan.due_at ? new Date(loan.due_at).toLocaleDateString() : '—'}</td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </section>
  );
}
