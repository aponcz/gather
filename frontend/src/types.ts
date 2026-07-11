export type Contact = {
  id: number;
  name: string;
  email: string;
  phone?: string | null;
};

export type LoanRecipient = {
  id: string | number;
  contact_id?: string | number | null;
  name: string;
  email: string;
  phone?: string | null;
};

export type UploadedFile = {
  id: number;
  filename: string;
  content_type: string;
  byte_size?: number | null;
  status: 'pending' | 'approved' | 'rejected';
  rejection_reason?: string | null;
  created_at?: string;
};

export type RequestItem = {
  id: number;
  section_name?: string | null;
  title: string;
  description?: string | null;
  kind: 'document' | 'form' | 'signature';
  required: boolean;
  due_at?: string | null;
  status?: string;
  uploaded_files?: UploadedFile[];
};

export type Loan = {
  id: number;
  title: string;
  message?: string | null;
  status: 'draft' | 'sent' | 'viewed' | 'completed' | 'cancelled';
  created_at?: string;
  due_at?: string | null;
  loan_amount_in_cents?: number | null;
  loan_type?: string | null;
  public_token?: string;
  brand_color?: string | null;
  logo_url?: string | null;
  contact?: Contact;
  contacts?: LoanRecipient[];
  request_items?: RequestItem[];
  audit_events?: AuditEvent[];
};

export type AuditEvent = {
  id: number;
  action: string;
  actor_email?: string | null;
  metadata?: Record<string, unknown>;
  created_at: string;
};

export type User = {
  id: number;
  name: string;
  email: string;
  role?: 'god' | 'admin' | 'customer';
  company_id?: number;
};

export type CompanyMember = {
  id: string;
  name: string;
  email: string;
  role: 'owner' | 'admin' | 'member';
  created_at: string;
  invitation_status: 'pending' | 'accepted';
};

export type Company = {
  id: string;
  name: string;
  phone_number?: string | null;
  address_line_1?: string | null;
  address_line_2?: string | null;
  city?: string | null;
  state?: string | null;
  zip_code?: string | null;
  website?: string | null;
  subdomain?: string | null;
  custom_domain?: string | null;
  logo?: string | null;
  trial_started_on?: string | null;
  activated_on?: string | null;
  delinquent_on?: string | null;
  suspended_on?: string | null;
};
