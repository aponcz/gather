import { ChangeEvent, useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import * as clientApi from '../api/clientPortal';
import { Invite } from '../types';
import { StatusBadge } from '../components/StatusBadge';

export function ClientInvite() {
  const { publicToken } = useParams();
  const [invite, setInvite] = useState<Invite | null>(null);
  const [uploading, setUploading] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function load() { if (publicToken) setInvite(await clientApi.getClientInvite(publicToken)); }
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
  if (!invite) return <div className="center-card">Loading client invite…</div>;

  return <section className="client-page">
    <div className="client-header" style={{ borderColor: invite.brand_color || undefined }}>
      {invite.logo_url && <img src={invite.logo_url} alt="Organization logo" />}
      <h1>{invite.title}</h1>
      <p>{invite.message}</p>
      {invite.due_at && <p className="muted">Due {new Date(invite.due_at).toLocaleDateString()}</p>}
    </div>
    <div className="card">
      <h2>Requested documents</h2>
      {invite.request_items?.map(item => <div className="client-item" key={item.id}>
        <div><strong>{item.title}</strong><p className="muted">{item.description || 'Upload the requested file.'}</p></div>
        <div>
          <input type="file" onChange={(event) => handleFile(item.id, event)} disabled={uploading === item.id} />
          {uploading === item.id && <span className="muted">Uploading…</span>}
        </div>
        <div className="file-list">
          {(item.uploaded_files || []).map(file => <div className="uploaded-file" key={file.id}><span>{file.filename}</span><StatusBadge status={file.status} /><button className="secondary" onClick={() => downloadFile(file.id)}>Download</button></div>)}
        </div>
      </div>)}
    </div>
  </section>;
}
