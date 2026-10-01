import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { ArrowRight, CheckCircle2, Clock3, FileCheck2, FileText, Plus, Sparkles } from 'lucide-react';
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
  const [loading, setLoading] = useState(true);

  function getPercentComplete(loan: Loan) {
    const totalRequestedDocuments = loan.request_items?.length || 0;
    const uploadedDocuments = (loan.request_items || []).filter((item) => (item.uploaded_files || []).length > 0).length;
    if (totalRequestedDocuments === 0) return 0;
    return Math.round((uploadedDocuments / totalRequestedDocuments) * 100);
  }

  useEffect(() => {
    adminApi.listLoans().then(setLoans).catch((err) => setError(err.message)).finally(() => setLoading(false));
  }, []);

  const inProgress = loans.filter((loan) => ['sent', 'viewed'].includes(loan.status)).length;
  const completed = loans.filter((loan) => loan.status === 'completed').length;

  return (
    <section className="loans-page">
      <div className="loans-orb loans-orb-one" /><div className="loans-orb loans-orb-two" />
      <header className="loans-hero">
        <div className="loans-hero-copy">
          <div className="marketing-eyebrow"><Sparkles size={15} /> Document collection</div>
          <h1>Every loan.<br /><span>Clearly in view.</span></h1>
          <p>Track every request, spot what needs attention, and keep client documents moving forward.</p>
        </div>
        <Link className="loans-create-button" to="/loans/new"><span><Plus size={18} /> Create loan</span><ArrowRight size={18} /></Link>
      </header>

      {error && <div className="error loans-error" role="alert">{error}</div>}

      <div className="loans-stats" aria-label="Loan summary">
        <article><div className="loans-stat-icon purple"><FileText size={21} /></div><div><strong>{loans.length}</strong><span>Total loans</span></div></article>
        <article><div className="loans-stat-icon amber"><Clock3 size={21} /></div><div><strong>{inProgress}</strong><span>In progress</span></div></article>
        <article><div className="loans-stat-icon green"><CheckCircle2 size={21} /></div><div><strong>{completed}</strong><span>Completed</span></div></article>
      </div>

      <section className="loans-list-panel">
        <div className="loans-list-heading">
          <div><span>Workspace</span><h2>Loan requests</h2></div>
          <p>{loans.length === 1 ? '1 loan' : `${loans.length} loans`} in this company</p>
        </div>
        <div className="loans-table-wrap">
        <table>
          <thead><tr><th>Loan</th><th>Client</th><th>Amount</th><th>Status</th><th>Progress</th><th>Due</th><th aria-label="Open loan" /></tr></thead>
          <tbody>
            {loading ? (
              <tr><td colSpan={7}><div className="loans-empty"><FileCheck2 size={25} /><span>Loading loans…</span></div></td></tr>
            ) : loans.length === 0 ? (
              <tr>
                <td colSpan={7}><div className="loans-empty"><div className="loans-empty-icon"><FileCheck2 size={25} /></div><strong>No loans yet</strong><span>Create your first loan to start collecting documents.</span><Link to="/loans/new">Create loan</Link></div></td>
              </tr>
            ) : (
              loans.map((loan) => {
                const percentComplete = getPercentComplete(loan);
                return <tr key={loan.id}>
                  <td><Link className="loans-title" to={`/loans/${loan.id}`}><span>{loan.title}</span><small>{loan.loan_type || 'Document request'}</small></Link></td>
                  <td>{loan.contact?.name ?? '—'}</td>
                  <td>{formatCurrencyFromCents(loan.loan_amount_in_cents)}</td>
                  <td><StatusBadge status={loan.status} /></td>
                  <td><div className="loans-progress"><div><i style={{ width: `${percentComplete}%` }} /></div><span>{percentComplete}%</span></div></td>
                  <td>{loan.due_at ? new Date(loan.due_at).toLocaleDateString() : '—'}</td>
                  <td><Link className="loans-open" to={`/loans/${loan.id}`} aria-label={`Open ${loan.title}`}><ArrowRight size={16} /></Link></td>
                </tr>;
              })
            )}
          </tbody>
        </table>
      </div>
      </section>
    </section>
  );
}
