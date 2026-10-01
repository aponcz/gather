import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { Activity, ArrowLeft, CalendarDays, Check, DollarSign, Download, Edit3, ExternalLink, FileCheck2, FileText, Link2, Send, Sparkles, Users, X } from 'lucide-react';
import * as adminApi from '../api/admin';
import { Contact, Loan, UploadedFile } from '../types';
import { StatusBadge } from '../components/StatusBadge';

function formatCurrencyFromCents(value?: number | null) {
  if (value === null || value === undefined) return '—';
  const amount = value / 100;

  return new Intl.NumberFormat(undefined, { style: 'currency', currency: 'USD', maximumFractionDigits: 2 }).format(amount);
}

export function LoanDetail() {
  const { id } = useParams();
  const [loan, setLoan] = useState<Loan | null>(null);
  const [contacts, setContacts] = useState<Contact[]>([]);
  const [selectedContactIds, setSelectedContactIds] = useState<string[]>([]);
  const [error, setError] = useState<string | null>(null);

  async function load() { if (id) setLoan(await adminApi.getLoan(id)); }
  async function loadContacts() { setContacts(await adminApi.listContacts()); }
  useEffect(() => {
    Promise.all([load(), loadContacts()]).catch((err) => setError(err.message));
  }, [id]);

  async function approve(file: UploadedFile) { await adminApi.approveFile(file.id); await load(); }
  async function reject(file: UploadedFile) { const reason = window.prompt('Reason for rejection?', 'Please upload a clearer copy.'); if (reason) { await adminApi.rejectFile(file.id, reason); await load(); } }
  async function download(file: UploadedFile) { const result = await adminApi.getDownloadUrl(file.id); window.open(result.url, '_blank'); }
  async function downloadAllFiles() {
    if (!loan) return;
    try {
      await adminApi.downloadAllFilesZip(loan.id);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Download failed');
    }
  }
  async function send() { if (loan) { await adminApi.sendLoan(loan.id); await load(); } }
  async function addContacts() {
    if (!loan || selectedContactIds.length === 0) return;
    try {
      const result = await adminApi.addLoanContacts(loan.id, { contact_ids: selectedContactIds });
      setLoan(result.loan);
      setSelectedContactIds([]);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not add contacts');
    }
  }

  if (error && !loan) return <div className="error">{error}</div>;
  if (!loan) return <div className="center-card">Loading loan…</div>;

  const portalUrl = loan.public_token ? `${window.location.origin}/client/loans/${loan.public_token}` : '';
  const recipients = (loan.contacts && loan.contacts.length > 0)
    ? loan.contacts
    : (loan.contact ? [loan.contact] : []);
  const recipientIdSet = new Set(
    recipients.map((contact) => String(('contact_id' in contact ? contact.contact_id : undefined) ?? contact.id))
  );
  const addableContacts = contacts.filter((contact) => !recipientIdSet.has(String(contact.id)));
  const totalRequestedDocuments = loan.request_items?.length || 0;
  const uploadedDocuments = (loan.request_items || []).filter((item) => (item.uploaded_files || []).length > 0).length;
  const percentComplete = totalRequestedDocuments > 0 ? Math.round((uploadedDocuments / totalRequestedDocuments) * 100) : 0;
  const groupedRequestedItems = (loan.request_items || []).reduce<Record<string, Loan['request_items']>>((groups, item) => {
    const sectionName = item.section_name?.trim() || 'Requested items';
    if (!groups[sectionName]) groups[sectionName] = [];
    groups[sectionName]!.push(item);
    return groups;
  }, {} as Record<string, NonNullable<Loan['request_items']>>);

  const sortedAuditEvents = [...(loan.audit_events || [])].sort(
    (firstEvent, secondEvent) => new Date(secondEvent.created_at).getTime() - new Date(firstEvent.created_at).getTime()
  );

  function formatAuditAction(action: string) {
    const actionLabels: Record<string, string> = {
      'loan.created': 'Loan created',
      'loan.updated': 'Loan updated',
      'loan.cancelled': 'Loan cancelled',
      'loan.viewed': 'Loan viewed',
      'loan.email_sent': 'Loan email sent',
      'file.uploaded': 'File uploaded',
      'request_item.created': 'Requested item added'
    };

    if (actionLabels[action]) return actionLabels[action];

    return action
      .replace(/[._]/g, ' ')
      .replace(/\b\w/g, (character) => character.toUpperCase());
  }

  function formatAuditEventText(event: { action: string; metadata?: Record<string, unknown> }) {
    const filename = typeof event.metadata?.filename === 'string' ? event.metadata.filename : null;
    const rejectionReason = typeof event.metadata?.reason === 'string' ? event.metadata.reason : null;

    if (event.action === 'file.uploaded') {
      return filename ? `File uploaded: ${filename}` : 'File uploaded';
    }

    if (event.action === 'file.approved') {
      return filename ? `File approved: ${filename}` : 'File approved';
    }

    if (event.action === 'file.rejected') {
      if (filename && rejectionReason) return `File rejected: ${filename} — reason: ${rejectionReason}`;
      if (filename) return `File rejected: ${filename}`;
      if (rejectionReason) return `File rejected — reason: ${rejectionReason}`;
      return 'File rejected';
    }

    return formatAuditAction(event.action);
  }

  return <section className="loan-show-page">
    <div className="loan-show-orb" />
    <div className="loan-show-content">
      <Link className="loan-show-back" to="/loans"><ArrowLeft size={16} /> All loans</Link>
      <header className="loan-show-hero">
        <div>
          <div className="marketing-eyebrow"><Sparkles size={15} /> Loan workspace</div>
          <h1>{loan.title}</h1>
          <div className="loan-show-subtitle"><StatusBadge status={loan.status} /><span>{recipients.length} {recipients.length === 1 ? 'recipient' : 'recipients'}</span></div>
        </div>
        <div className="loan-show-actions">
          <Link className="loan-show-edit" to={`/loans/${loan.id}/edit`}><Edit3 size={16} /> Edit loan</Link>
          <button className="loan-show-send" onClick={send}><Send size={16} /> Send loan</button>
        </div>
      </header>

      {error && <div className="error loan-show-error" role="alert">{error}</div>}

      <div className="loan-show-metrics">
        <article><span><DollarSign size={18} /></span><div><small>Loan amount</small><strong>{formatCurrencyFromCents(loan.loan_amount_in_cents)}</strong></div></article>
        <article><span><FileText size={18} /></span><div><small>Loan type</small><strong>{loan.loan_type || 'Not specified'}</strong></div></article>
        <article><span><CalendarDays size={18} /></span><div><small>Due date</small><strong>{loan.due_at ? new Date(loan.due_at).toLocaleDateString() : 'No due date'}</strong></div></article>
        <article className="loan-show-progress-metric"><div><small>Documents received</small><strong>{uploadedDocuments} of {totalRequestedDocuments}</strong></div><b>{percentComplete}%</b></article>
      </div>

      <div className="loan-show-grid">
        <section className="loan-show-panel loan-review-panel">
          <div className="loan-panel-heading">
            <div><span>Collection progress</span><h2>Requested items</h2></div>
            <button onClick={downloadAllFiles}><Download size={16} /> Download all</button>
          </div>
          <div className="loan-review-progress"><div role="progressbar" aria-valuemin={0} aria-valuemax={100} aria-valuenow={percentComplete} aria-label="Upload completion"><i style={{ width: `${percentComplete}%` }} /></div><strong>{percentComplete}% complete</strong></div>

          {Object.keys(groupedRequestedItems).length === 0 && <div className="loan-show-empty"><FileCheck2 size={24} /> No requested items yet.</div>}
          {Object.keys(groupedRequestedItems).map((sectionName) => <div className="loan-review-section" key={sectionName}>
            <h3>{sectionName}</h3>
            {(groupedRequestedItems[sectionName] || []).map(item => {
              const files = item.uploaded_files || [];
              return <article className="loan-review-item" key={item.id}>
                <div className={files.length > 0 ? 'loan-review-icon received' : 'loan-review-icon'}>{files.length > 0 ? <Check size={17} /> : <FileText size={17} />}</div>
                <div className="loan-review-body">
                  <div className="loan-review-title"><strong>{item.title}</strong>{item.required && <span>Required</span>}</div>
                  <p>{item.description || 'No description'}</p>
                  {files.length === 0 ? <div className="loan-awaiting-file">Awaiting client upload</div> : <div className="loan-review-files">
                    {files.map(file => <div className="loan-review-file" key={file.id}>
                      <FileCheck2 size={17} /><span title={file.filename}>{file.filename}</span><StatusBadge status={file.status} />
                      <div className="loan-file-actions">
                        <button onClick={() => download(file)} title="Download"><Download size={15} /><span>Download</span></button>
                        <button className="approve" onClick={() => approve(file)} title="Approve"><Check size={15} /><span>Approve</span></button>
                        <button className="reject" onClick={() => reject(file)} title="Reject"><X size={15} /><span>Reject</span></button>
                      </div>
                    </div>)}
                  </div>}
                </div>
              </article>;
            })}
          </div>)}
        </section>

        <aside className="loan-show-sidebar">
          <section className="loan-show-panel">
            <div className="loan-side-heading"><span><Users size={17} /></span><div><h2>Recipients</h2><p>People receiving this request</p></div></div>
            <div className="loan-recipient-list">
              {recipients.length === 0 && <p className="loan-side-empty">No recipients added.</p>}
              {recipients.map(contact => <div className="loan-recipient" key={contact.id}><span>{contact.name.charAt(0).toUpperCase()}</span><div><strong>{contact.name}</strong><small>{contact.email}</small></div></div>)}
            </div>
            {addableContacts.length > 0 && <div className="loan-add-recipients">
              <label>Add contacts
                <select multiple value={selectedContactIds} onChange={(event) => setSelectedContactIds(Array.from(event.target.selectedOptions).map((option) => option.value))}>
                  {addableContacts.map(contact => <option key={contact.id} value={contact.id}>{contact.name} · {contact.email}</option>)}
                </select>
              </label>
              <button onClick={addContacts} disabled={selectedContactIds.length === 0}><Users size={15} /> Add selected</button>
            </div>}
          </section>

          <section className="loan-show-panel">
            <div className="loan-side-heading"><span><Link2 size={17} /></span><div><h2>Client portal</h2><p>Secure document upload link</p></div></div>
            {portalUrl ? <><code className="loan-portal-url">{portalUrl}</code><Link className="loan-portal-open" to={portalUrl.replace(window.location.origin, '')}><ExternalLink size={15} /> Open client portal</Link></> : <p className="loan-side-empty">The portal link will be available when this loan is ready.</p>}
          </section>
        </aside>
      </div>

      <section className="loan-show-panel loan-activity-panel">
        <div className="loan-panel-heading"><div><span>History</span><h2>Activity</h2></div><Activity size={20} /></div>
        {sortedAuditEvents.length === 0 && <div className="loan-show-empty">No activity recorded yet.</div>}
        <div className="loan-activity-list">{sortedAuditEvents.map(event => <div className="loan-activity" key={event.id}>
          <i /><div><strong>{formatAuditEventText(event)}</strong><p>by {event.actor_email || 'unknown actor'}</p></div><time>{new Date(event.created_at).toLocaleString()}</time>
        </div>)}</div>
      </section>
    </div>
  </section>;
}
