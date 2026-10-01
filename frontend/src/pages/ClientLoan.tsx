import { ChangeEvent, CSSProperties, useEffect, useRef, useState } from 'react';
import { Link, useLocation, useParams } from 'react-router-dom';
import { Check, Clock3, Download, FileCheck2, FileText, ShieldCheck, Sparkles, UploadCloud } from 'lucide-react';
import * as clientApi from '../api/clientPortal';
import { Loan, RequestItem } from '../types';
import { StatusBadge } from '../components/StatusBadge';
import { clientTokenKey, setToken } from '../lib/storage';

function formatCurrencyFromCents(value?: number | null) {
  if (value === null || value === undefined) return null;
  const amount = value / 100;

  return new Intl.NumberFormat(undefined, { style: 'currency', currency: 'USD', maximumFractionDigits: 2 }).format(amount);
}

export function ClientLoan() {
  const { publicToken } = useParams();
  const location = useLocation();
  const [loan, setLoan] = useState<Loan | null>(null);
  const [uploading, setUploading] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);
  const loadRef = useRef<{ publicToken: string; promise: Promise<Loan> } | null>(null);

  async function load() { if (publicToken) setLoan(await clientApi.getClientLoan(publicToken)); }
  useEffect(() => {
    if (!publicToken) return;

    if (loadRef.current?.publicToken !== publicToken) {
      loadRef.current = {
        publicToken,
        promise: (async () => {
          const magicToken = new URLSearchParams(location.search).get('magic_token') ||
            new URLSearchParams(location.hash.slice(1)).get('magic_token');
          if (magicToken) {
            const session = await clientApi.createClientSession(magicToken);
            setToken(clientTokenKey, session.token);
            window.history.replaceState(null, '', location.pathname);
          }
          return clientApi.getClientLoan(publicToken);
        })(),
      };
    }

    let active = true;
    loadRef.current.promise
      .then((result) => { if (active) setLoan(result); })
      .catch((err) => { if (active) setError(err instanceof Error ? err.message : 'Unable to open this request'); });
    return () => { active = false; };
  }, [location.hash, location.pathname, location.search, publicToken]);

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

  if (error && !loan) return <div className="client-portal-state"><div className="client-state-mark"><FileCheck2 size={24} /></div><div className="error">{error}</div><Link to="/client">Sign in to client portal</Link></div>;
  if (!loan) return <div className="client-portal-state"><div className="client-state-mark"><FileCheck2 size={24} /></div><span>Loading your document request…</span></div>;

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

  return <div className="client-portal" style={{ '--client-accent': loan.brand_color || '#7544ed' } as CSSProperties}>
    <div className="client-portal-orb client-portal-orb-one" /><div className="client-portal-orb client-portal-orb-two" />
    <header className="client-portal-nav">
      <div className="marketing-brand">
        <span className="marketing-brand-mark"><FileCheck2 size={21} /></span>
        <span>ProText <strong>Gather</strong></span>
      </div>
      <span className="client-secure"><ShieldCheck size={16} /><span>Secure client portal</span></span>
    </header>

    <main className="client-portal-main">
      <section className="client-portal-hero">
        <div className="client-hero-copy">
          <div className="marketing-eyebrow"><Sparkles size={15} /> Document request</div>
          {loan.logo_url && <img className="client-company-logo" src={loan.logo_url} alt="Company logo" />}
          <h1>{loan.title}</h1>
          {loan.message && <p className="client-hero-message">{loan.message}</p>}
          <div className="client-loan-meta">
            {(loanAmount || loan.loan_type) && <span><FileText size={16} /> {[loanAmount, loan.loan_type].filter(Boolean).join(' · ')}</span>}
            {loan.due_at && <span><Clock3 size={16} /> Due {new Date(loan.due_at).toLocaleDateString()}</span>}
          </div>
        </div>

        <aside className="client-progress-card">
          <div className="client-progress-top">
            <div><span>Your progress</span><strong>{percentComplete}% complete</strong></div>
            <div className={percentComplete === 100 ? 'client-progress-icon complete' : 'client-progress-icon'}>{percentComplete === 100 ? <Check size={24} /> : <UploadCloud size={24} />}</div>
          </div>
          <div className="client-progress-track" role="progressbar" aria-valuemin={0} aria-valuemax={100} aria-valuenow={percentComplete} aria-label="Upload completion">
            <div style={{ width: `${percentComplete}%` }} />
          </div>
          <p><strong>{uploadedDocuments}</strong> of {totalRequestedDocuments} requested items uploaded</p>
        </aside>
      </section>

      <section className="client-request-panel">
        <div className="client-panel-heading">
          <div><span>What we need</span><h2>Requested documents</h2></div>
          <p>Choose a file for each item below. Your uploads are securely added to this request.</p>
        </div>
        {error && <div className="error client-request-error" role="alert">{error}</div>}

        {Object.keys(groupedRequestedItems).map((sectionName) => <div className="client-section-group" key={sectionName}>
          <h3>{sectionName}</h3>
          <div className="client-request-list">
            {groupedRequestedItems[sectionName].map(item => {
              const files = item.uploaded_files || [];
              const hasFiles = files.length > 0;
              const inputId = `request-file-${item.id}`;
              return <article className={hasFiles ? 'client-request-card has-file' : 'client-request-card'} key={item.id}>
                <div className="client-request-status">{hasFiles ? <Check size={19} /> : <FileText size={19} />}</div>
                <div className="client-request-copy">
                  <div className="client-request-title"><strong>{item.title}</strong>{item.required && <span>Required</span>}</div>
                  <p>{item.description || 'Upload the requested file.'}</p>
                  {files.length > 0 && <div className="client-file-list">
                    {files.map(file => <div className="client-uploaded-file" key={file.id}>
                      <FileCheck2 size={17} /><span title={file.filename}>{file.filename}</span><StatusBadge status={file.status} />
                      <button type="button" onClick={() => downloadFile(file.id)} aria-label={`Download ${file.filename}`}><Download size={16} /><span>Download</span></button>
                    </div>)}
                  </div>}
                </div>
                <div className="client-upload-control">
                  <input id={inputId} type="file" onChange={(event) => handleFile(item.id, event)} disabled={uploading === item.id} />
                  <label htmlFor={inputId}><UploadCloud size={17} /> {uploading === item.id ? 'Uploading…' : hasFiles ? 'Upload another' : 'Choose file'}</label>
                </div>
              </article>;
            })}
          </div>
        </div>)}
      </section>
    </main>

    <footer className="client-portal-footer"><ShieldCheck size={15} /><span>Your files are transferred securely through ProText Gather.</span></footer>
  </div>;
}
