import { FormEvent, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import * as adminApi from '../api/admin';
import { Contact } from '../types';

type DraftItem = { title: string; description: string; kind: string; required: boolean };
type DraftSection = { name: string; items: DraftItem[] };
type FormErrors = { recipients?: string; title?: string };

function dollarsToCents(value: string) {
  const amount = Number(value);
  if (!Number.isFinite(amount)) return undefined;

  return Math.round(amount * 100);
}

export function NewLoan() {
  const navigate = useNavigate();
  const [contacts, setContacts] = useState<Contact[]>([]);
  const [form, setForm] = useState({
    contact_ids: [] as string[],
    title: 'SBA Loan Package',
    message: 'Please upload the requested documents.',
    due_at: '',
    loan_amount: '',
    loan_type: ''
  });
  const [recipients, setRecipients] = useState<Array<{ name: string; email: string; phone: string }>>([{ name: '', email: '', phone: '' }]);
  const [sections, setSections] = useState<DraftSection[]>([
    {
      name: 'Requested documents',
      items: [
        { title: 'Tax Returns', description: 'Most recent two years', kind: 'document', required: true },
        { title: 'Bank Statements', description: 'Last three months', kind: 'document', required: true }
      ]
    }
  ]);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [formErrors, setFormErrors] = useState<FormErrors>({});

  useEffect(() => { adminApi.listContacts().then(setContacts).catch((err) => setError(err.message)); }, []);

  function updateSectionName(sectionIndex: number, name: string) {
    setSections(sections.map((section, index) => (index === sectionIndex ? { ...section, name } : section)));
  }

  function updateItem(sectionIndex: number, itemIndex: number, patch: Partial<DraftItem>) {
    setSections(sections.map((section, index) => {
      if (index !== sectionIndex) return section;
      return {
        ...section,
        items: section.items.map((item, innerIndex) => (innerIndex === itemIndex ? { ...item, ...patch } : item))
      };
    }));
  }

  function addSection() {
    setSections([...sections, { name: '', items: [{ title: '', description: '', kind: 'document', required: true }] }]);
  }

  function addItem(sectionIndex: number) {
    setSections(sections.map((section, index) => {
      if (index !== sectionIndex) return section;
      return {
        ...section,
        items: [...section.items, { title: '', description: '', kind: 'document', required: true }]
      };
    }));
  }

  function updateRecipient(index: number, patch: Partial<{ name: string; email: string; phone: string }>) {
    if (patch.email !== undefined) {
      setFormErrors((current) => ({ ...current, recipients: undefined }));
    }
    setRecipients(recipients.map((recipient, recipientIndex) => (recipientIndex === index ? { ...recipient, ...patch } : recipient)));
  }

  function addRecipient() {
    setRecipients([...recipients, { name: '', email: '', phone: '' }]);
  }

  function removeRecipient(index: number) {
    setRecipients(recipients.filter((_, recipientIndex) => recipientIndex !== index));
  }

  async function submit(event: FormEvent) {
    event.preventDefault();
    setError(null);

    const enteredEmails = recipients.map((recipient) => recipient.email.trim()).filter(Boolean);
    const nextErrors: FormErrors = {};
    if (form.contact_ids.length === 0 && enteredEmails.length === 0) {
      nextErrors.recipients = 'Enter at least one recipient email or select an additional recipient.';
    } else if (enteredEmails.some((email) => !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))) {
      nextErrors.recipients = 'Enter a valid email address for each recipient.';
    }
    if (!form.title.trim()) {
      nextErrors.title = 'Enter a title for the loan.';
    }

    setFormErrors(nextErrors);
    if (Object.keys(nextErrors).length > 0) return;

    setSubmitting(true);
    try {
      const loan = await adminApi.createLoan({
        contact_ids: form.contact_ids,
        recipients: recipients
          .map((recipient) => ({
            name: recipient.name.trim(),
            email: recipient.email.trim(),
            phone: recipient.phone.trim() || undefined
          }))
          .filter((recipient) => recipient.email),
        title: form.title.trim(),
        message: form.message,
        due_at: form.due_at ? new Date(form.due_at).toISOString() : undefined,
        loan_amount_in_cents: form.loan_amount.trim() ? dollarsToCents(form.loan_amount) : undefined,
        loan_type: form.loan_type.trim() || undefined,
        request_items: sections.flatMap((section) => section.items
          .filter((item) => item.title.trim())
          .map((item) => ({
            ...item,
            section_name: section.name.trim() || undefined
          })))
      });

      navigate(`/loans/${loan.id}`);
    } catch (err) { setError(err instanceof Error ? err.message : 'Could not create loan'); }
    finally { setSubmitting(false); }
  }

  return <section>
    <h1>Create loan</h1>
    <form className="card form-stack" onSubmit={submit} noValidate>
      <h2>Recipients</h2>
      {recipients.map((recipient, index) => (
        <div className="request-row" key={`recipient-${index}`}>
          <input placeholder="Name" value={recipient.name} onChange={(e) => updateRecipient(index, { name: e.target.value })} />
          <input
            placeholder="Email"
            type="email"
            value={recipient.email}
            onChange={(e) => updateRecipient(index, { email: e.target.value })}
            aria-invalid={Boolean(formErrors.recipients)}
            aria-describedby={formErrors.recipients ? 'recipients-error' : undefined}
          />
          <input placeholder="Phone" value={recipient.phone} onChange={(e) => updateRecipient(index, { phone: e.target.value })} />
          <button type="button" className="secondary" onClick={() => removeRecipient(index)} disabled={recipients.length === 1}>Remove</button>
        </div>
      ))}
      <button type="button" className="secondary" onClick={addRecipient}>Add recipient</button>
      <label>Additional Recipients
        <select
          multiple
          value={form.contact_ids}
          onChange={(e) => {
            const selected = Array.from(e.target.selectedOptions).map((option) => option.value);
            setFormErrors((current) => ({ ...current, recipients: undefined }));
            setForm({ ...form, contact_ids: selected });
          }}
          aria-invalid={Boolean(formErrors.recipients)}
          aria-describedby={formErrors.recipients ? 'recipients-error' : undefined}
        >
          {contacts.map(c => <option key={c.id} value={c.id}>{c.name} — {c.email}</option>)}
        </select>
      </label>
      {formErrors.recipients && <div className="field-error" id="recipients-error">{formErrors.recipients}</div>}


      <label>Title
        <input
          value={form.title}
          onChange={(e) => {
            setFormErrors((current) => ({ ...current, title: undefined }));
            setForm({ ...form, title: e.target.value });
          }}
          aria-invalid={Boolean(formErrors.title)}
          aria-describedby={formErrors.title ? 'title-error' : undefined}
        />
        {formErrors.title && <span className="field-error" id="title-error">{formErrors.title}</span>}
      </label>
      <div className="form-grid-two">
        <label>Loan amount<input type="number" min="0" step="0.01" value={form.loan_amount} onChange={(e) => setForm({ ...form, loan_amount: e.target.value })} /></label>
        <label>Loan type<input placeholder="e.g. SBA 7(a)" value={form.loan_type} onChange={(e) => setForm({ ...form, loan_type: e.target.value })} /></label>
      </div>
      <label>Message<textarea value={form.message} onChange={(e) => setForm({ ...form, message: e.target.value })} /></label>
      <label>Due date<input type="datetime-local" value={form.due_at} onChange={(e) => setForm({ ...form, due_at: e.target.value })} /></label>
      <h2>Requested items</h2>
      {sections.map((section, sectionIndex) => <div className="item-card" key={sectionIndex}>
        <label>Section name
          <input placeholder="e.g. Financial Statements" value={section.name} onChange={(e) => updateSectionName(sectionIndex, e.target.value)} />
        </label>
        {section.items.map((item, itemIndex) => <div className="request-row" key={`${sectionIndex}-${itemIndex}`}>
          <input placeholder="Document title" value={item.title} onChange={(e) => updateItem(sectionIndex, itemIndex, { title: e.target.value })} />
          <input placeholder="Description" value={item.description} onChange={(e) => updateItem(sectionIndex, itemIndex, { description: e.target.value })} />
          <select value={item.kind} onChange={(e) => updateItem(sectionIndex, itemIndex, { kind: e.target.value })}><option value="document">Document</option><option value="form">Form</option><option value="signature">Signature</option></select>
          <label className="inline"><input type="checkbox" checked={item.required} onChange={(e) => updateItem(sectionIndex, itemIndex, { required: e.target.checked })} /> Required</label>
        </div>)}
        <button type="button" className="secondary" onClick={() => addItem(sectionIndex)}>Add item</button>
      </div>)}
      <button type="button" className="secondary" onClick={addSection}>Add section</button>
      {error && <div className="error">{error}</div>}
      <button
        className="primary"
        disabled={submitting}
      >
        {submitting ? 'Creating draft…' : 'Create Draft'}
      </button>
    </form>
  </section>;
}
