import { FormEvent, useEffect, useState } from 'react';
import { ContactRound, Mail, Pencil, Phone, Plus, Save, Sparkles, Trash2, UserRound, X } from 'lucide-react';
import * as adminApi from '../api/admin';
import { Contact } from '../types';

export function Contacts() {
  const [contacts, setContacts] = useState<Contact[]>([]);
  const [form, setForm] = useState({ name: '', email: '', phone: '' });
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [editingContact, setEditingContact] = useState<Contact | null>(null);
  const [deletingContactId, setDeletingContactId] = useState<string | number | null>(null);

  async function load() { setContacts(await adminApi.listContacts()); }
  useEffect(() => { load().catch((err) => setError(err.message)).finally(() => setLoading(false)); }, []);

  async function submit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    setSaving(true);
    try {
      if (editingContact) {
        await adminApi.updateContact(editingContact.id, form);
      } else {
        await adminApi.createContact(form);
      }
      setForm({ name: '', email: '', phone: '' });
      setEditingContact(null);
      await load();
    } catch (err) { setError(err instanceof Error ? err.message : 'Could not create contact'); }
    finally { setSaving(false); }
  }

  function editContact(contact: Contact) {
    setEditingContact(contact);
    setForm({ name: contact.name, email: contact.email, phone: contact.phone || '' });
    setError(null);
  }

  function cancelEditing() {
    setEditingContact(null);
    setForm({ name: '', email: '', phone: '' });
    setError(null);
  }

  async function deleteContact(contact: Contact) {
    if (!window.confirm(`Delete ${contact.name}? Existing loan history will be preserved.`)) return;
    setDeletingContactId(contact.id);
    setError(null);
    try {
      await adminApi.deleteContact(contact.id);
      if (editingContact?.id === contact.id) cancelEditing();
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not delete contact');
    } finally {
      setDeletingContactId(null);
    }
  }

  return <section className="workspace-page contacts-page">
    <div className="workspace-orb" />
    <header className="workspace-hero">
      <div><div className="marketing-eyebrow"><Sparkles size={15} /> Client relationships</div><h1>Everyone you work with.<br /><span>All in one place.</span></h1><p>Keep client details organized and ready when it is time to start a new document request.</p></div>
      <div className="workspace-hero-icon"><ContactRound size={31} /></div>
    </header>

    <div className="contacts-grid">
      <form className="workspace-panel contact-form" onSubmit={submit}>
        <div className="workspace-panel-heading"><div><span>{editingContact ? 'Update client' : 'New client'}</span><h2>{editingContact ? 'Edit contact' : 'Add a contact'}</h2></div>{editingContact && <button className="contact-cancel-edit" type="button" onClick={cancelEditing} aria-label="Cancel editing"><X size={16} /></button>}</div>
        <div className="workspace-form-body">
          <label><span><UserRound size={14} /> Name</span><input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="Full name" required /></label>
          <label><span><Mail size={14} /> Email</span><input type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} placeholder="name@example.com" required /></label>
          <label><span><Phone size={14} /> Phone</span><input value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} placeholder="Optional" /></label>
        </div>
        {error && <div className="error">{error}</div>}
        <div className="workspace-form-actions"><button className="workspace-primary" disabled={saving}>{editingContact ? <Save size={16} /> : <Plus size={16} />}{saving ? 'Saving…' : editingContact ? 'Save changes' : 'Save contact'}</button></div>
      </form>

      <div className="workspace-panel workspace-table-panel contacts-directory">
        <div className="workspace-panel-heading"><div><span>Directory</span><h2>Contacts</h2></div><p>{contacts.length} {contacts.length === 1 ? 'contact' : 'contacts'}</p></div>
        <table><thead><tr><th>Contact</th><th>Email</th><th>Phone</th><th aria-label="Contact actions" /></tr></thead><tbody>
          {loading ? (
            <tr><td colSpan={4}><div className="workspace-empty">Loading contacts…</div></td></tr>
          ) : contacts.length === 0 ? (
            <tr>
              <td colSpan={4}><div className="contacts-empty"><div><ContactRound size={22} /></div><strong>No contacts yet</strong><span>Add your first contact to get started.</span></div></td>
            </tr>
          ) : (
            contacts.map(c => <tr key={c.id}><td><div className="contact-identity"><span>{c.name.charAt(0).toUpperCase()}</span><strong>{c.name}</strong></div></td><td><a href={`mailto:${c.email}`}>{c.email}</a></td><td>{c.phone || '—'}</td><td><div className="contact-row-actions"><button type="button" onClick={() => editContact(c)} aria-label={`Edit ${c.name}`}><Pencil size={15} /></button><button className="delete" type="button" onClick={() => void deleteContact(c)} disabled={deletingContactId === c.id} aria-label={`Delete ${c.name}`}><Trash2 size={15} /></button></div></td></tr>)
          )}
        </tbody></table>
      </div>
    </div>
  </section>;
}
