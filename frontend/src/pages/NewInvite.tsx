import { FormEvent, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import * as adminApi from '../api/admin';
import { Contact } from '../types';

type DraftItem = { title: string; description: string; kind: string; required: boolean };

export function NewInvite() {
  const navigate = useNavigate();
  const [contacts, setContacts] = useState<Contact[]>([]);
  const [form, setForm] = useState({ contact_id: '', title: 'SBA Loan Package', message: 'Please upload the requested documents.', due_at: '' });
  const [items, setItems] = useState<DraftItem[]>([
    { title: 'Tax Returns', description: 'Most recent two years', kind: 'document', required: true },
    { title: 'Bank Statements', description: 'Last three months', kind: 'document', required: true }
  ]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => { adminApi.listContacts().then(setContacts).catch((err) => setError(err.message)); }, []);

  function updateItem(index: number, patch: Partial<DraftItem>) {
    setItems(items.map((item, i) => i === index ? { ...item, ...patch } : item));
  }

  async function submit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    try {
      const invite = await adminApi.createInvite({
        contact_id: form.contact_id,
        title: form.title,
        message: form.message,
        due_at: form.due_at ? new Date(form.due_at).toISOString() : undefined,
        request_items: items.filter(i => i.title.trim())
      });
      navigate(`/invites/${invite.id}`);
    } catch (err) { setError(err instanceof Error ? err.message : 'Could not create invite'); }
  }

  return <section>
    <h1>Create invite</h1>
    <form className="card form-stack" onSubmit={submit}>
      <label>Client
        <select value={form.contact_id} onChange={(e) => setForm({ ...form, contact_id: e.target.value })} required>
          <option value="">Select a contact</option>
          {contacts.map(c => <option key={c.id} value={c.id}>{c.name} — {c.email}</option>)}
        </select>
      </label>
      <label>Title<input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} required /></label>
      <label>Message<textarea value={form.message} onChange={(e) => setForm({ ...form, message: e.target.value })} /></label>
      <label>Due date<input type="datetime-local" value={form.due_at} onChange={(e) => setForm({ ...form, due_at: e.target.value })} /></label>
      <h2>Requested items</h2>
      {items.map((item, index) => <div className="request-row" key={index}>
        <input placeholder="Document title" value={item.title} onChange={(e) => updateItem(index, { title: e.target.value })} />
        <input placeholder="Description" value={item.description} onChange={(e) => updateItem(index, { description: e.target.value })} />
        <select value={item.kind} onChange={(e) => updateItem(index, { kind: e.target.value })}><option value="document">Document</option><option value="form">Form</option><option value="signature">Signature</option></select>
        <label className="inline"><input type="checkbox" checked={item.required} onChange={(e) => updateItem(index, { required: e.target.checked })} /> Required</label>
      </div>)}
      <button type="button" className="secondary" onClick={() => setItems([...items, { title: '', description: '', kind: 'document', required: true }])}>Add item</button>
      {error && <div className="error">{error}</div>}
      <button className="primary">Create invite</button>
    </form>
  </section>;
}
