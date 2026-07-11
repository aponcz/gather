import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
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

  if (error) return <div className="error">{error}</div>;
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

  return <section>
    <div className="page-header">
      <div>
        <h1>{loan.title}</h1>
        {recipients.length > 0 ? (
          <div className="muted">
            <p><strong>Recipients ({recipients.length})</strong></p>
            {recipients.map((contact) => (
              <p key={contact.id}>{contact.name} · {contact.email}</p>
            ))}
          </div>
        ) : (
          <p className="muted">No recipients</p>
        )}
      </div>
      <div className="actions"><StatusBadge status={loan.status} /><button className="primary" onClick={send}>Send loan</button></div>
    </div>
    <div className="card">
      <h2>Loan details</h2>
      <div className="detail-grid">
        <div><span className="muted">Amount</span><strong>{formatCurrencyFromCents(loan.loan_amount_in_cents)}</strong></div>
        <div><span className="muted">Type</span><strong>{loan.loan_type || '—'}</strong></div>
      </div>
    </div>
    <div className="card">
      <h2>Client portal link</h2>
      <p className="muted">Use this after requesting a client magic link/session.</p>
      <code>{portalUrl}</code>
      <p><Link to={portalUrl.replace(window.location.origin, '')}>Open client portal route</Link></p>
    </div>
    <div className="card">
      <h2>Add recipients</h2>
      <label>Select additional contacts
        <select
          multiple
          value={selectedContactIds}
          onChange={(event) => {
            const selected = Array.from(event.target.selectedOptions).map((option) => option.value);
            setSelectedContactIds(selected);
          }}
        >
          {addableContacts.map((contact) => (
            <option key={contact.id} value={contact.id}>{contact.name} · {contact.email}</option>
          ))}
        </select>
      </label>
      <div className="actions" style={{ marginTop: '12px' }}>
        <button className="secondary" onClick={addContacts} disabled={selectedContactIds.length === 0}>Add selected contacts</button>
      </div>
    </div>
    <div className="card">
      <h2>Requested items</h2>
      <div className="actions" style={{ marginBottom: '12px' }}>
        <button className="secondary" onClick={downloadAllFiles}>Download all files (.zip)</button>
      </div>
      <div className="progress-meta">
        <span>{uploadedDocuments} of {totalRequestedDocuments} uploaded</span>
        <strong>{percentComplete}%</strong>
      </div>
      <div className="progress-track" role="progressbar" aria-valuemin={0} aria-valuemax={100} aria-valuenow={percentComplete} aria-label="Upload completion">
        <div className="progress-fill" style={{ width: `${percentComplete}%` }} />
      </div>
      {Object.keys(groupedRequestedItems).map((sectionName) => <div className="section-group" key={sectionName}>
        <h3 className="section-title">{sectionName}</h3>
        {(groupedRequestedItems[sectionName] || []).map(item => <div className="item-card" key={item.id}>
          <div><strong>{item.title}</strong><p className="muted">{item.description || 'No description'} {item.required ? '· required' : ''}</p></div>
          <div className="file-list">
            {(item.uploaded_files || []).length === 0 && <span className="muted">No files uploaded yet.</span>}
            {(item.uploaded_files || []).map(file => <div className="uploaded-file" key={file.id}>
              <span>{file.filename}</span><StatusBadge status={file.status} />
              <button className="secondary" onClick={() => download(file)}>Download</button>
              <button className="secondary" onClick={() => approve(file)}>Approve</button>
              <button className="danger" onClick={() => reject(file)}>Reject</button>
            </div>)}
          </div>
        </div>)}
      </div>)}
    </div>
    <div className="card">
      <h2>Audit trail</h2>
      {sortedAuditEvents.map(event => (
        <div className="audit" key={event.id}>
          <div>
            <strong>{formatAuditEventText(event)}</strong>
            <p className="muted">by {event.actor_email || 'unknown actor'}</p>
          </div>
          <span>{new Date(event.created_at).toLocaleString()}</span>
        </div>
      ))}
    </div>
  </section>;
}
