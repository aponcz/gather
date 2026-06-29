import { FormEvent, useEffect, useState } from 'react';
import * as adminApi from '../api/admin';
import { Contact } from '../types';

export function Contacts() {
  const [contacts, setContacts] = useState<Contact[]>([]);
  const [form, setForm] = useState({ name: '', email: '', phone: '' });
  const [error, setError] = useState<string | null>(null);

  async function load() { setContacts(await adminApi.listContacts()); }
  useEffect(() => { load().catch((err) => setError(err.message)); }, []);

  async function submit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    try {
      await adminApi.createContact(form);
      setForm({ name: '', email: '', phone: '' });
      await load();
    } catch (err) { setError(err instanceof Error ? err.message : 'Could not create contact'); }
  }

  return <section>
    <h1>Contacts</h1>
    <div className="grid-two">
      <form className="card" onSubmit={submit}>
        <h2>Add contact</h2>
        <label>Name<input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required /></label>
        <label>Email<input type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} required /></label>
        <label>Phone<input value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} /></label>
        {error && <div className="error">{error}</div>}
        <button className="primary">Save contact</button>
      </form>
      <div className="card table-card">
        <table><thead><tr><th>Name</th><th>Email</th><th>Phone</th></tr></thead><tbody>
          {contacts.map(c => <tr key={c.id}><td>{c.name}</td><td>{c.email}</td><td>{c.phone || '—'}</td></tr>)}
        </tbody></table>
      </div>
    </div>
  </section>;
}
