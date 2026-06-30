export type Contact = {
  id: number;
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

export type Invite = {
  id: number;
  title: string;
  message?: string | null;
  status: 'draft' | 'sent' | 'viewed' | 'completed' | 'cancelled';
  due_at?: string | null;
  public_token?: string;
  brand_color?: string | null;
  logo_url?: string | null;
  contact?: Contact;
  request_items?: RequestItem[];
  audit_events?: AuditEvent[];
};

export type AuditEvent = {
  id: number;
  action: string;
  metadata?: Record<string, unknown>;
  created_at: string;
};

export type User = {
  id: number;
  name: string;
  email: string;
  organization_id?: number;
};
