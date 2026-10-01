import { FormEvent, useEffect, useState } from 'react';
import { Building2, Check, Save, Settings2, Sparkles, UserPlus, Users } from 'lucide-react';
import * as adminApi from '../api/admin';
import { ApiError } from '../api/client';
import { CompanyMember } from '../types';

type CompanyForm = {
  name: string;
  phone_number: string;
  address_line_1: string;
  address_line_2: string;
  city: string;
  state: string;
  zip_code: string;
  website: string;
  subdomain: string;
  logo: string;
};

const emptyForm: CompanyForm = {
  name: '',
  phone_number: '',
  address_line_1: '',
  address_line_2: '',
  city: '',
  state: '',
  zip_code: '',
  website: '',
  subdomain: '',
  logo: ''
};

function roleLabel(role: 'owner' | 'admin' | 'member') {
  if (role === 'owner') return 'Owner';
  if (role === 'admin') return 'Admin';
  return 'Member';
}

export function Company() {
  const [activeTab, setActiveTab] = useState<'general' | 'members' | 'current_members'>('general');
  const [form, setForm] = useState<CompanyForm>(emptyForm);
  const [memberName, setMemberName] = useState('');
  const [memberEmail, setMemberEmail] = useState('');
  const [memberRole, setMemberRole] = useState<'owner' | 'admin' | 'member'>('member');
  const [companyMembers, setCompanyMembers] = useState<CompanyMember[]>([]);
  const [membersLoading, setMembersLoading] = useState(false);
  const [updatingMemberId, setUpdatingMemberId] = useState<string | null>(null);
  const [membersError, setMembersError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [invitingMember, setInvitingMember] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [memberError, setMemberError] = useState<string | null>(null);
  const [memberSuccess, setMemberSuccess] = useState<string | null>(null);

  useEffect(() => {
    async function load() {
      try {
        const company = await adminApi.getCompany();
        setForm({
          name: company.name ?? '',
          phone_number: company.phone_number ?? '',
          address_line_1: company.address_line_1 ?? '',
          address_line_2: company.address_line_2 ?? '',
          city: company.city ?? '',
          state: company.state ?? '',
          zip_code: company.zip_code ?? '',
          website: company.website ?? '',
          subdomain: company.subdomain ?? '',
          logo: company.logo ?? ''
        });
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Could not load company details');
      } finally {
        setLoading(false);
      }
    }

    load();
  }, []);

  async function submit(event: FormEvent) {
    event.preventDefault();
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      await adminApi.updateCompany(form);
      setSuccess('Company details saved.');
    } catch (err) {
      if (err instanceof ApiError && err.body && typeof err.body === 'object') {
        const body = err.body as { details?: string[]; error?: string };
        if (body.details && body.details.length > 0) {
          setError(body.details.join(', '));
        } else {
          setError(body.error || err.message);
        }
      } else {
        setError(err instanceof Error ? err.message : 'Could not save company details');
      }
    } finally {
      setSaving(false);
    }
  }

  async function inviteMember(event: FormEvent) {
    event.preventDefault();
    setInvitingMember(true);
    setMemberError(null);
    setMemberSuccess(null);

    try {
      const invitedMember = await adminApi.inviteCompanyMember({
        name: memberName,
        email: memberEmail,
        role: memberRole
      });

      setMemberSuccess(`Invitation sent to ${invitedMember.email}.`);
      setMemberName('');
      setMemberEmail('');
      setMemberRole('member');
      void loadMembers();
    } catch (err) {
      if (err instanceof ApiError && err.body && typeof err.body === 'object') {
        const body = err.body as { details?: string[]; error?: string };
        if (body.details && body.details.length > 0) {
          setMemberError(body.details.join(', '));
        } else {
          setMemberError(body.error || err.message);
        }
      } else {
        setMemberError(err instanceof Error ? err.message : 'Could not invite member');
      }
    } finally {
      setInvitingMember(false);
    }
  }

  async function loadMembers() {
    setMembersLoading(true);
    setMembersError(null);
    try {
      const members = await adminApi.listCompanyMembers();
      setCompanyMembers(members);
    } catch (err) {
      setMembersError(err instanceof Error ? err.message : 'Could not load current members');
    } finally {
      setMembersLoading(false);
    }
  }

  async function updateMemberRole(memberId: string, role: 'owner' | 'admin' | 'member') {
    setUpdatingMemberId(memberId);
    setMembersError(null);
    try {
      const updated = await adminApi.updateCompanyMemberRole(memberId, role);
      setCompanyMembers((members) => members.map((member) => (member.id === memberId ? updated : member)));
    } catch (err) {
      setMembersError(err instanceof Error ? err.message : 'Could not update member role');
      void loadMembers();
    } finally {
      setUpdatingMemberId(null);
    }
  }

  useEffect(() => {
    if (activeTab === 'current_members' || activeTab === 'members') {
      void loadMembers();
    }
  }, [activeTab]);

  if (loading) {
    return <section className="workspace-state"><div className="workspace-state-icon"><Building2 size={23} /></div><span>Loading company details…</span></section>;
  }

  return (
    <section className="workspace-page company-page">
      <div className="workspace-orb" />
      <header className="workspace-hero">
        <div><div className="marketing-eyebrow"><Sparkles size={15} /> Company workspace</div><h1>Make Gather<br /><span>feel like yours.</span></h1><p>Manage your company profile, brand details, and the people who can access your workspace.</p></div>
        <div className="workspace-hero-icon"><Building2 size={31} /></div>
      </header>

      <div className="workspace-tabs" role="tablist" aria-label="Company settings">
        <button
          type="button"
          className={activeTab === 'general' ? 'active' : ''}
          onClick={() => setActiveTab('general')}
          role="tab" aria-selected={activeTab === 'general'}
        >
          <Settings2 size={16} /> General
        </button>
        <button
          type="button"
          className={activeTab === 'members' ? 'active' : ''}
          onClick={() => setActiveTab('members')}
          role="tab" aria-selected={activeTab === 'members'}
        >
          <UserPlus size={16} /> Invite
        </button>
        <button
          type="button"
          className={activeTab === 'current_members' ? 'active' : ''}
          onClick={() => setActiveTab('current_members')}
          role="tab" aria-selected={activeTab === 'current_members'}
        >
          <Users size={16} /> Members
        </button>
      </div>
      {activeTab === 'general' ? (
        <form className="workspace-panel company-form" onSubmit={submit}>
          <div className="workspace-panel-heading"><div><span>Profile</span><h2>Company details</h2></div><p>These details identify your company throughout Gather.</p></div>
          <div className="company-form-grid">
            <label className="company-field-wide">Company name<input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required /></label>
            <label>Phone number<input value={form.phone_number} onChange={(e) => setForm({ ...form, phone_number: e.target.value })} /></label>
            <label>Website<input value={form.website} onChange={(e) => setForm({ ...form, website: e.target.value })} /></label>
            <label className="company-field-wide">Address line 1<input value={form.address_line_1} onChange={(e) => setForm({ ...form, address_line_1: e.target.value })} /></label>
            <label className="company-field-wide">Address line 2<input value={form.address_line_2} onChange={(e) => setForm({ ...form, address_line_2: e.target.value })} /></label>
            <label>City<input value={form.city} onChange={(e) => setForm({ ...form, city: e.target.value })} /></label>
            <label>State<input value={form.state} onChange={(e) => setForm({ ...form, state: e.target.value })} /></label>
            <label>ZIP code<input value={form.zip_code} onChange={(e) => setForm({ ...form, zip_code: e.target.value })} /></label>
          </div>
          <div className="company-brand-fields"><div><span>Brand & portal</span><p>Customize how clients find and recognize your workspace.</p></div><div className="company-form-grid"><label>Subdomain<input value={form.subdomain} onChange={(e) => setForm({ ...form, subdomain: e.target.value })} /></label><label>Logo URL<input value={form.logo} onChange={(e) => setForm({ ...form, logo: e.target.value })} /></label></div></div>
          {error && <div className="error">{error}</div>}
          {success && <div className="workspace-success"><Check size={16} />{success}</div>}
          <div className="workspace-form-actions"><button className="workspace-primary" disabled={saving}><Save size={16} />{saving ? 'Saving…' : 'Save company'}</button></div>
        </form>
      ) : activeTab === 'members' ? (
        <div className="company-invite-grid">
          <form className="workspace-panel company-invite-form" onSubmit={inviteMember}>
            <div className="workspace-panel-heading"><div><span>New teammate</span><h2>Invite a member</h2></div></div>
            <div className="workspace-form-body"><label>Name<input value={memberName} onChange={(e) => setMemberName(e.target.value)} required /></label><label>Email<input type="email" value={memberEmail} onChange={(e) => setMemberEmail(e.target.value)} required /></label><label>Role<select value={memberRole} onChange={(e) => setMemberRole(e.target.value as 'owner' | 'admin' | 'member')}><option value="owner">Owner</option><option value="admin">Admin</option><option value="member">Member</option></select></label></div>
            {memberError && <div className="error">{memberError}</div>}
            {memberSuccess && <div className="workspace-success"><Check size={16} />{memberSuccess}</div>}
            <div className="workspace-form-actions"><button className="workspace-primary" disabled={invitingMember}><UserPlus size={16} />{invitingMember ? 'Sending invite…' : 'Send invite'}</button></div>
          </form>

          <div className="workspace-panel workspace-table-panel">
            <div className="workspace-panel-heading"><div><span>Access</span><h2>Invitations</h2></div></div>
            {membersLoading ? (
              <p className="workspace-empty">Loading invitations…</p>
            ) : membersError ? (
              <div className="error">{membersError}</div>
            ) : companyMembers.length === 0 ? (
              <p className="workspace-empty">No invitations found.</p>
            ) : (
              <table>
                <thead>
                  <tr>
                    <th>Name</th>
                    <th>Email</th>
                    <th>Role</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {companyMembers.map((member) => (
                    <tr key={member.id}>
                      <td>{member.name}</td>
                      <td>{member.email}</td>
                      <td>{roleLabel(member.role)}</td>
                      <td>{member.invitation_status}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>
      ) : (
        <div className="workspace-panel workspace-table-panel">
          <div className="workspace-panel-heading"><div><span>Team access</span><h2>Current members</h2></div><p>{companyMembers.length} {companyMembers.length === 1 ? 'member' : 'members'}</p></div>
          {membersLoading ? (
            <p className="workspace-empty">Loading members…</p>
          ) : membersError ? (
            <div className="error">{membersError}</div>
          ) : companyMembers.length === 0 ? (
            <p className="workspace-empty">No members found.</p>
          ) : (
            <table>
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Email</th>
                  <th>Role</th>
                </tr>
              </thead>
              <tbody>
                {companyMembers.map((member) => (
                  <tr key={member.id}>
                    <td>{member.name}</td>
                    <td>{member.email}</td>
                    <td>
                      <select
                        value={member.role}
                        disabled={updatingMemberId === member.id}
                        onChange={(e) => void updateMemberRole(member.id, e.target.value as 'owner' | 'admin' | 'member')}
                      >
                        <option value="owner">Owner</option>
                        <option value="admin">Admin</option>
                        <option value="member">Member</option>
                      </select>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}
    </section>
  );
}
