import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import * as adminApi from '../api/admin';
import { CompanyMember } from '../types';

type MembershipRole = 'owner' | 'admin' | 'member';

function roleLabel(role: MembershipRole) {
  if (role === 'owner') return 'Owner';
  if (role === 'admin') return 'Admin';
  return 'Member';
}

export function ManageUsers() {
  const [companyMembers, setCompanyMembers] = useState<CompanyMember[]>([]);
  const [membersLoading, setMembersLoading] = useState(false);
  const [updatingMemberId, setUpdatingMemberId] = useState<string | null>(null);
  const [membersError, setMembersError] = useState<string | null>(null);

  async function loadMembers() {
    setMembersLoading(true);
    setMembersError(null);
    try {
      const members = await adminApi.listCompanyMembers();
      setCompanyMembers(members);
    } catch (err) {
      setMembersError(err instanceof Error ? err.message : 'Could not load users');
    } finally {
      setMembersLoading(false);
    }
  }

  useEffect(() => {
    void loadMembers();
  }, []);

  async function updateMemberRole(memberId: string, role: MembershipRole) {
    setUpdatingMemberId(memberId);
    setMembersError(null);
    try {
      const updated = await adminApi.updateCompanyMemberRole(memberId, role);
      setCompanyMembers((members) => members.map((member) => (member.id === memberId ? updated : member)));
    } catch (err) {
      setMembersError(err instanceof Error ? err.message : 'Could not update user role');
      void loadMembers();
    } finally {
      setUpdatingMemberId(null);
    }
  }

  return (
    <section className="form-stack" style={{ maxWidth: 900 }}>
      <p className="muted"><Link to="/admin">Admin Dashboard</Link> / Manage Users</p>
      <h1>Manage Users</h1>
      <p className="muted">Review users and update membership roles.</p>

      <div className="card table-card">
        {membersLoading ? (
          <p className="muted">Loading users…</p>
        ) : membersError ? (
          <div className="error">{membersError}</div>
        ) : companyMembers.length === 0 ? (
          <p className="muted">No users found.</p>
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
                  <td>
                    <select
                      value={member.role}
                      disabled={updatingMemberId === member.id}
                      onChange={(e) => void updateMemberRole(member.id, e.target.value as MembershipRole)}
                    >
                      <option value="owner">Owner</option>
                      <option value="admin">Admin</option>
                      <option value="member">Member</option>
                    </select>
                    <div className="muted" style={{ marginTop: 4 }}>{roleLabel(member.role)}</div>
                  </td>
                  <td>{member.invitation_status}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </section>
  );
}
