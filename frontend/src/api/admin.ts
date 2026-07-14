import { apiFetch, apiFetchBlob } from './client';
import { Company, CompanyMember, Contact, Loan, UploadedFile, User } from '../types';

type LoanRecipientInput = { name: string; email: string; phone?: string };
type RequestItemInput = { title: string; description?: string; kind: string; required: boolean; section_name?: string };

type AuthResponse = {
  token: string;
  user: User;
  company: Company;
  companies: Company[];
};

export function login(email: string, password: string) {
  return apiFetch<AuthResponse>('/api/v1/auth/login', {
    method: 'POST',
    auth: false,
    body: JSON.stringify({ email, password })
  });
}

export function getProTextAuthorizationUrl() {
  return apiFetch<{ authorization_url: string }>('/api/v1/auth/oauth/goprotext/start', {
    method: 'GET',
    auth: false
  });
}

export function register(payload: {
  company_name: string;
  name: string;
  email: string;
  password: string;
  phone_number?: string;
  address_line_1?: string;
  address_line_2?: string;
  city?: string;
  state?: string;
  zip_code?: string;
  website?: string;
  subdomain?: string;
  custom_domain?: string;
  status?: number;
  logo?: string;
  trial_started_on?: string;
  activated_on?: string;
  delinquent_on?: string;
  suspended_on?: string;
}) {
  return apiFetch<AuthResponse>('/api/v1/auth/register', {
    method: 'POST',
    auth: false,
    body: JSON.stringify(payload)
  });
}

export function me() {
  return apiFetch<{ user: User; company: Company; companies: Company[] }>('/api/v1/me');
}

export function switchCompany(companyId: string) {
  return apiFetch<AuthResponse>('/api/v1/auth/switch-company', {
    method: 'POST',
    body: JSON.stringify({ company_id: companyId })
  });
}

export function getCompany() {
  return apiFetch<Company>('/api/v1/company');
}

export function updateCompany(payload: {
  name: string;
  phone_number?: string;
  address_line_1?: string;
  address_line_2?: string;
  city?: string;
  state?: string;
  zip_code?: string;
  website?: string;
  subdomain?: string;
  custom_domain?: string;
  logo?: string;
  trial_started_on?: string;
  activated_on?: string;
  delinquent_on?: string;
  suspended_on?: string;
}) {
  return apiFetch<Company>('/api/v1/company', {
    method: 'PATCH',
    body: JSON.stringify({ company: payload })
  });
}

export function listCompanies() {
  return apiFetch<Company[]>('/api/v1/companies');
}

export function listAllUsers() {
  return apiFetch<User[]>('/api/v1/users');
}

export function updateUserRole(id: number | string, role: 'god' | 'admin' | 'customer') {
  return apiFetch<User>(`/api/v1/users/${id}`, {
    method: 'PATCH',
    body: JSON.stringify({ role })
  });
}

export function inviteCompanyMember(payload: { name: string; email: string; role: 'owner' | 'admin' | 'member' }) {
  return apiFetch<CompanyMember>('/api/v1/company_members', {
    method: 'POST',
    body: JSON.stringify(payload)
  });
}

export function listCompanyMembers() {
  return apiFetch<CompanyMember[]>('/api/v1/company_members');
}

export function updateCompanyMemberRole(id: string, role: 'owner' | 'admin' | 'member') {
  return apiFetch<CompanyMember>(`/api/v1/company_members/${id}`, {
    method: 'PATCH',
    body: JSON.stringify({ role })
  });
}

export function listContacts() {
  return apiFetch<Contact[]>('/api/v1/contacts');
}

export function createContact(payload: { name: string; email: string; phone?: string }) {
  return apiFetch<Contact>('/api/v1/contacts', { method: 'POST', body: JSON.stringify(payload) });
}

export function listLoans() {
  return apiFetch<Loan[]>('/api/v1/loans');
}

export function getLoan(id: string | number) {
  return apiFetch<Loan>(`/api/v1/loans/${id}`);
}

export function updateLoan(id: string | number, payload: {
  contact_ids?: string[];
  recipients?: LoanRecipientInput[];
  title: string;
  message?: string;
  due_at?: string | null;
  loan_amount_in_cents?: number | null;
  loan_type?: string | null;
  request_items?: Array<RequestItemInput & { id?: string | number }>;
}) {
  return apiFetch<Loan>(`/api/v1/loans/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(payload)
  });
}

export function createLoan(payload: {
  contact_id?: string;
  contact_ids?: string[];
  recipients?: LoanRecipientInput[];
  title: string;
  message?: string;
  due_at?: string;
  loan_amount_in_cents?: number;
  loan_type?: string;
  request_items: RequestItemInput[];
}) {
  return apiFetch<Loan>('/api/v1/loans', { method: 'POST', body: JSON.stringify(payload) });
}

export function bulkCreateLoans(payload: {
  contact_ids?: string[];
  recipients?: LoanRecipientInput[];
  title: string;
  message?: string;
  due_at?: string;
  loan_amount_in_cents?: number;
  loan_type?: string;
  request_items: RequestItemInput[];
}) {
  return apiFetch<{ loan: Loan; contact_count: number; message: string }>('/api/v1/loans/bulk_create', { method: 'POST', body: JSON.stringify(payload) });
}

export function sendLoan(id: string | number) {
  return apiFetch<{ status: string; loan: Loan }>(`/api/v1/loans/${id}/send_loan`, { method: 'POST' });
}

export function addLoanContacts(id: string | number, payload: { contact_ids?: string[]; recipients?: LoanRecipientInput[] }) {
  return apiFetch<{ loan: Loan; added_contact_count: number }>(`/api/v1/loans/${id}/add_contacts`, {
    method: 'POST',
    body: JSON.stringify(payload)
  });
}

export function cancelLoan(id: number) {
  return apiFetch<Loan>(`/api/v1/loans/${id}/cancel`, { method: 'POST' });
}

export function approveFile(id: number) {
  return apiFetch<UploadedFile>(`/api/v1/uploaded_files/${id}/approve`, { method: 'POST' });
}

export function rejectFile(id: number, reason: string) {
  return apiFetch<UploadedFile>(`/api/v1/uploaded_files/${id}/reject`, { method: 'POST', body: JSON.stringify({ reason }) });
}

export function getDownloadUrl(id: number) {
  return apiFetch<{ url: string }>(`/api/v1/uploaded_files/${id}/download_url`);
}

export async function downloadAllFilesZip(loanId: number) {
  const { blob, filename } = await apiFetchBlob(`/api/v1/loans/${loanId}/download_all_files`);
  const url = window.URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = filename || 'document-collection-files.zip';
  document.body.appendChild(anchor);
  anchor.click();
  anchor.remove();
  window.URL.revokeObjectURL(url);
}
