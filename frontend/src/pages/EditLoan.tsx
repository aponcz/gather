import { FormEvent, useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import * as adminApi from '../api/admin';
import { Contact, Loan } from '../types';

type DraftItem = { id?: string | number; title: string; description: string; kind: string; required: boolean };
type DraftSection = { name: string; items: DraftItem[] };
type Recipient = { name: string; email: string; phone: string };
type EditLoanForm = {
  contact_ids: string[];
  title: string;
  message: string;
  due_at: string;
  loan_amount: string;
  loan_type: string;
};
type FormErrors = { recipients?: string; title?: string };

function centsToDollars(value?: number | null) {
  return value === null || value === undefined ? '' : (value / 100).toFixed(2);
}

function dollarsToCents(value: string) {
  const amount = Number(value);
  return Number.isFinite(amount) ? Math.round(amount * 100) : null;
}

function toLocalDateTime(value?: string | null) {
  if (!value) return '';

  const date = new Date(value);
  const localDate = new Date(date.getTime() - date.getTimezoneOffset() * 60_000);
  return localDate.toISOString().slice(0, 16);
}

function sectionsFromLoan(loan: Loan): DraftSection[] {
  const sections = new Map<string, DraftItem[]>();
  (loan.request_items || []).forEach((item) => {
    const sectionName = item.section_name?.trim() || 'Requested items';
    const sectionItems = sections.get(sectionName) || [];
    sectionItems.push({
      id: item.id,
      title: item.title,
      description: item.description || '',
      kind: item.kind,
      required: item.required
    });
    sections.set(sectionName, sectionItems);
  });

  const result = Array.from(sections, ([name, items]) => ({ name, items }));
  return result.length > 0 ? result : [{ name: 'Requested documents', items: [{ title: '', description: '', kind: 'document', required: true }] }];
}

export function EditLoan() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [contacts, setContacts] = useState<Contact[]>([]);
  const [form, setForm] = useState<EditLoanForm | null>(null);
  const [recipients, setRecipients] = useState<Recipient[]>([]);
  const [sections, setSections] = useState<DraftSection[]>([]);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [formErrors, setFormErrors] = useState<FormErrors>({});

  useEffect(() => {
    if (!id) return;

    Promise.all([adminApi.getLoan(id), adminApi.listContacts()])
      .then(([loan, availableContacts]) => {
        const loanRecipients = loan.contacts || [];
        const directRecipients = loanRecipients
          .filter((recipient) => !recipient.contact_id)
          .map((recipient) => ({ name: recipient.name, email: recipient.email, phone: recipient.phone || '' }));

        setContacts(availableContacts);
        setRecipients(directRecipients.length > 0 ? directRecipients : [{ name: '', email: '', phone: '' }]);
        setSections(sectionsFromLoan(loan));
        setForm({
          contact_ids: loanRecipients.flatMap((recipient) => recipient.contact_id ? [String(recipient.contact_id)] : []),
          title: loan.title,
          message: loan.message || '',
          due_at: toLocalDateTime(loan.due_at),
          loan_amount: centsToDollars(loan.loan_amount_in_cents),
          loan_type: loan.loan_type || ''
        });
      })
      .catch((requestError) => setError(requestError instanceof Error ? requestError.message : 'Could not load loan'));
  }, [id]);

  function updateForm(patch: Partial<EditLoanForm>) {
    if (patch.title !== undefined) setFormErrors((current) => ({ ...current, title: undefined }));
    if (patch.contact_ids !== undefined) setFormErrors((current) => ({ ...current, recipients: undefined }));
    setForm((current) => current ? { ...current, ...patch } : current);
  }

  function updateRecipient(index: number, patch: Partial<Recipient>) {
    if (patch.email !== undefined) setFormErrors((current) => ({ ...current, recipients: undefined }));
    setRecipients((current) => current.map((recipient, recipientIndex) => recipientIndex === index ? { ...recipient, ...patch } : recipient));
  }

  function updateSectionName(sectionIndex: number, name: string) {
    setSections((current) => current.map((section, index) => index === sectionIndex ? { ...section, name } : section));
  }

  function updateItem(sectionIndex: number, itemIndex: number, patch: Partial<DraftItem>) {
    setSections((current) => current.map((section, index) => index === sectionIndex ? {
      ...section,
      items: section.items.map((item, innerIndex) => innerIndex === itemIndex ? { ...item, ...patch } : item)
    } : section));
  }

  function addSection() {
    setSections((current) => [...current, { name: '', items: [{ title: '', description: '', kind: 'document', required: true }] }]);
  }

  function addItem(sectionIndex: number) {
    setSections((current) => current.map((section, index) => index === sectionIndex ? {
      ...section,
      items: [...section.items, { title: '', description: '', kind: 'document', required: true }]
    } : section));
  }

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!id || !form) return;

    const enteredEmails = recipients.map((recipient) => recipient.email.trim()).filter(Boolean);
    const nextErrors: FormErrors = {};
    if (form.contact_ids.length === 0 && enteredEmails.length === 0) {
      nextErrors.recipients = 'Enter at least one recipient email or select an additional recipient.';
    } else if (enteredEmails.some((email) => !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))) {
      nextErrors.recipients = 'Enter a valid email address for each recipient.';
    }
    if (!form.title.trim()) nextErrors.title = 'Enter a title for the loan.';
    setFormErrors(nextErrors);
    if (Object.keys(nextErrors).length > 0) return;

    setError(null);
    setSubmitting(true);
    try {
      await adminApi.updateLoan(id, {
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
        due_at: form.due_at ? new Date(form.due_at).toISOString() : null,
        loan_amount_in_cents: form.loan_amount.trim() ? dollarsToCents(form.loan_amount) : null,
        loan_type: form.loan_type.trim() || null,
        request_items: sections.flatMap((section) => section.items
          .filter((item) => item.title.trim())
          .map((item) => ({ ...item, title: item.title.trim(), section_name: section.name.trim() || undefined })))
      });
      navigate(`/loans/${id}`);
    } catch (requestError) {
      setError(requestError instanceof Error ? requestError.message : 'Could not update loan');
    } finally {
      setSubmitting(false);
    }
  }

  if (error && !form) return <div className="error">{error}</div>;
  if (!form) return <div className="center-card">Loading loan…</div>;

  return <section>
    <div className="page-header"><h1>Edit loan</h1></div>
    <form className="card form-stack" onSubmit={submit} noValidate>
      <h2>Recipients</h2>
      {recipients.map((recipient, index) => <div className="request-row" key={`recipient-${index}`}>
        <input placeholder="Name" value={recipient.name} onChange={(event) => updateRecipient(index, { name: event.target.value })} />
        <input
          placeholder="Email"
          type="email"
          value={recipient.email}
          onChange={(event) => updateRecipient(index, { email: event.target.value })}
          aria-invalid={Boolean(formErrors.recipients)}
          aria-describedby={formErrors.recipients ? 'edit-recipients-error' : undefined}
        />
        <input placeholder="Phone" value={recipient.phone} onChange={(event) => updateRecipient(index, { phone: event.target.value })} />
        <button type="button" className="secondary" onClick={() => setRecipients((current) => current.filter((_, recipientIndex) => recipientIndex !== index))} disabled={recipients.length === 1}>Remove</button>
      </div>)}
      <button type="button" className="secondary" onClick={() => setRecipients((current) => [...current, { name: '', email: '', phone: '' }])}>Add recipient</button>
      <label>Additional Recipients
        <select
          multiple
          value={form.contact_ids}
          onChange={(event) => updateForm({ contact_ids: Array.from(event.target.selectedOptions).map((option) => option.value) })}
          aria-invalid={Boolean(formErrors.recipients)}
          aria-describedby={formErrors.recipients ? 'edit-recipients-error' : undefined}
        >
          {contacts.map((contact) => <option key={contact.id} value={contact.id}>{contact.name} — {contact.email}</option>)}
        </select>
      </label>
      {formErrors.recipients && <div className="field-error" id="edit-recipients-error">{formErrors.recipients}</div>}

      <label>Title
        <input value={form.title} onChange={(event) => updateForm({ title: event.target.value })} aria-invalid={Boolean(formErrors.title)} aria-describedby={formErrors.title ? 'edit-title-error' : undefined} />
        {formErrors.title && <span className="field-error" id="edit-title-error">{formErrors.title}</span>}
      </label>
      <div className="form-grid-two">
        <label>Loan amount<input type="number" min="0" step="0.01" value={form.loan_amount} onChange={(event) => updateForm({ loan_amount: event.target.value })} /></label>
        <label>Loan type<input value={form.loan_type} onChange={(event) => updateForm({ loan_type: event.target.value })} /></label>
      </div>
      <label>Message<textarea value={form.message} onChange={(event) => updateForm({ message: event.target.value })} /></label>
      <label>Due date<input type="datetime-local" value={form.due_at} onChange={(event) => updateForm({ due_at: event.target.value })} /></label>

      <h2>Requested items</h2>
      {sections.map((section, sectionIndex) => <div className="item-card" key={sectionIndex}>
        <label>Section name<input value={section.name} onChange={(event) => updateSectionName(sectionIndex, event.target.value)} /></label>
        {section.items.map((item, itemIndex) => <div className="request-row" key={item.id || `${sectionIndex}-${itemIndex}`}>
          <input placeholder="Document title" value={item.title} onChange={(event) => updateItem(sectionIndex, itemIndex, { title: event.target.value })} />
          <input placeholder="Description" value={item.description} onChange={(event) => updateItem(sectionIndex, itemIndex, { description: event.target.value })} />
          <select value={item.kind} onChange={(event) => updateItem(sectionIndex, itemIndex, { kind: event.target.value })}>
            <option value="document">Document</option><option value="form">Form</option><option value="signature">Signature</option>
          </select>
          <label className="inline"><input type="checkbox" checked={item.required} onChange={(event) => updateItem(sectionIndex, itemIndex, { required: event.target.checked })} /> Required</label>
        </div>)}
        <button type="button" className="secondary" onClick={() => addItem(sectionIndex)}>Add item</button>
      </div>)}
      <button type="button" className="secondary" onClick={addSection}>Add section</button>

      {error && <div className="error">{error}</div>}
      <div className="actions">
        <button className="primary" disabled={submitting}>{submitting ? 'Saving…' : 'Save changes'}</button>
        <Link className="secondary" to={`/loans/${id}`}>Cancel</Link>
      </div>
    </form>
  </section>;
}
