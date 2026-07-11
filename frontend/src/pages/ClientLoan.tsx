import { ChangeEvent, useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import * as clientApi from '../api/clientPortal';
import { Loan, RequestItem } from '../types';
import { StatusBadge } from '../components/StatusBadge';

function formatCurrencyFromCents(value?: number | null) {
  if (value === null || value === undefined) return null;
  const amount = value / 100;

  return new Intl.NumberFormat(undefined, { style: 'currency', currency: 'USD', maximumFractionDigits: 2 }).format(amount);
}

export function ClientLoan() {
  const { publicToken } = useParams();
  const [loan, setLoan] = useState<Loan | null>(null);
  const [uploading, setUploading] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function load() { if (publicToken) setLoan(await clientApi.getClientLoan(publicToken)); }
  useEffect(() => { load().catch((err) => setError(err.message)); }, [publicToken]);

  async function handleFile(itemId: number, event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    if (!file) return;
    setUploading(itemId);
    setError(null);
    try {
      await clientApi.uploadRequestItem(itemId, file);
      await load();
    } catch (err) { setError(err instanceof Error ? err.message : 'Upload failed'); }
    finally { setUploading(null); }
  }

  async function downloadFile(fileId: number) {
    setError(null);
    try {
      const result = await clientApi.getUploadedFileDownloadUrl(fileId);
      window.open(result.url, '_blank');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Download failed');
    }
  }

  if (error) return <div className="center-card"><div className="error">{error}</div><Link to="/client">Sign in to client portal</Link></div>;
  if (!loan) return <div className="center-card">Loading client loan…</div>;

  const totalRequestedDocuments = loan.request_items?.length || 0;
  const uploadedDocuments = (loan.request_items || []).filter((item) => (item.uploaded_files || []).length > 0).length;
  const percentComplete = totalRequestedDocuments > 0 ? Math.round((uploadedDocuments / totalRequestedDocuments) * 100) : 0;
  const groupedRequestedItems = (loan.request_items || []).reduce<Record<string, RequestItem[]>>((groups, item) => {
    const sectionName = item.section_name?.trim() || 'Requested items';
    if (!groups[sectionName]) groups[sectionName] = [];
    groups[sectionName].push(item);
    return groups;
  }, {});
  const loanAmount = formatCurrencyFromCents(loan.loan_amount_in_cents);

  return <section className="client-page">
    <div className="client-header" style={{ borderColor: loan.brand_color || undefined }}>
      {loan.logo_url && <img src={loan.logo_url} alt="Company logo" />}
      <h1>{loan.title}</h1>
      <p>{loan.message}</p>
      {(loanAmount || loan.loan_type) && (
        <p className="muted">{[loanAmount, loan.loan_type].filter(Boolean).join(' · ')}</p>
      )}
      {loan.due_at && <p className="muted">Due {new Date(loan.due_at).toLocaleDateString()}</p>}
    </div>
    <div className="card">
      <h2>Requested documents</h2>
      <div className="progress-meta">
        <span>{uploadedDocuments} of {totalRequestedDocuments} uploaded</span>
        <strong>{percentComplete}%</strong>
      </div>
      <div className="progress-track" role="progressbar" aria-valuemin={0} aria-valuemax={100} aria-valuenow={percentComplete} aria-label="Upload completion">
        <div className="progress-fill" style={{ width: `${percentComplete}%` }} />
      </div>
      {Object.keys(groupedRequestedItems).map((sectionName) => <div className="section-group" key={sectionName}>
        <h3 className="section-title">{sectionName}</h3>
        {groupedRequestedItems[sectionName].map(item => <div className="client-item" key={item.id}>
          <div><strong>{item.title}</strong><p className="muted">{item.description || 'Upload the requested file.'}</p></div>
          <div>
            <input type="file" onChange={(event) => handleFile(item.id, event)} disabled={uploading === item.id} />
            {uploading === item.id && <span className="muted">Uploading…</span>}
          </div>
          <div className="file-list">
            {(item.uploaded_files || []).map(file => <div className="uploaded-file" key={file.id}><span>{file.filename}</span><StatusBadge status={file.status} /><button className="secondary" onClick={() => downloadFile(file.id)}>Download</button></div>)}
          </div>
        </div>)}
      </div>)}
    </div>
  </section>;
}
