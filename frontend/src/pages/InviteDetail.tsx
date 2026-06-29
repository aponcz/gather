import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import * as adminApi from '../api/admin';
import { Invite, UploadedFile } from '../types';
import { StatusBadge } from '../components/StatusBadge';

export function InviteDetail() {
  const { id } = useParams();
  const [invite, setInvite] = useState<Invite | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function load() { if (id) setInvite(await adminApi.getInvite(id)); }
  useEffect(() => { load().catch((err) => setError(err.message)); }, [id]);

  async function approve(file: UploadedFile) { await adminApi.approveFile(file.id); await load(); }
  async function reject(file: UploadedFile) { const reason = window.prompt('Reason for rejection?', 'Please upload a clearer copy.'); if (reason) { await adminApi.rejectFile(file.id, reason); await load(); } }
  async function download(file: UploadedFile) { const result = await adminApi.getDownloadUrl(file.id); window.open(result.url, '_blank'); }
  async function send() { if (invite) { await adminApi.sendInvite(invite.id); await load(); } }

  if (error) return <div className="error">{error}</div>;
  if (!invite) return <div className="center-card">Loading invite…</div>;

  const portalUrl = invite.public_token ? `${window.location.origin}/client/invites/${invite.public_token}` : '';

  return <section>
    <div className="page-header">
      <div><h1>{invite.title}</h1><p className="muted">{invite.contact?.name} · {invite.contact?.email}</p></div>
      <div className="actions"><StatusBadge status={invite.status} /><button className="primary" onClick={send}>Send invite</button></div>
    </div>
    <div className="card">
      <h2>Client portal link</h2>
      <p className="muted">Use this after requesting a client magic link/session.</p>
      <code>{portalUrl}</code>
      <p><Link to={portalUrl.replace(window.location.origin, '')}>Open client portal route</Link></p>
    </div>
    <div className="card">
      <h2>Requested items</h2>
      {invite.request_items?.map(item => <div className="item-card" key={item.id}>
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
    </div>
    <div className="card">
      <h2>Audit trail</h2>
      {(invite.audit_events || []).map(event => <div className="audit" key={event.id}><strong>{event.action}</strong><span>{new Date(event.created_at).toLocaleString()}</span></div>)}
    </div>
  </section>;
}
