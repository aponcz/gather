import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import * as adminApi from '../api/admin';
import { User } from '../types';

type UserRole = 'god' | 'admin' | 'customer';

function roleLabel(role: UserRole) {
  if (role === 'god') return 'God';
  if (role === 'admin') return 'Admin';
  return 'Customer';
}

export function ManageUsers() {
  const [users, setUsers] = useState<User[]>([]);
  const [usersLoading, setUsersLoading] = useState(false);
  const [updatingUserId, setUpdatingUserId] = useState<number | null>(null);
  const [usersError, setUsersError] = useState<string | null>(null);

  async function loadUsers() {
    setUsersLoading(true);
    setUsersError(null);
    try {
      const allUsers = await adminApi.listAllUsers();
      setUsers(allUsers);
    } catch (err) {
      setUsersError(err instanceof Error ? err.message : 'Could not load users');
    } finally {
      setUsersLoading(false);
    }
  }

  useEffect(() => {
    void loadUsers();
  }, []);

  async function updateUserRole(userId: number, role: UserRole) {
    setUpdatingUserId(userId);
    setUsersError(null);
    try {
      const updated = await adminApi.updateUserRole(userId, role);
      setUsers((prevUsers) => prevUsers.map((user) => (user.id === userId ? updated : user)));
    } catch (err) {
      setUsersError(err instanceof Error ? err.message : 'Could not update user role');
      void loadUsers();
    } finally {
      setUpdatingUserId(null);
    }
  }

  return (
    <section className="form-stack" style={{ maxWidth: 900 }}>
      <p className="muted"><Link to="/admin">Admin Dashboard</Link> / Manage Users</p>
      <h1>Manage Users</h1>
      <p className="muted">Review all system users and update roles.</p>

      <div className="card table-card">
        {usersLoading ? (
          <p className="muted">Loading users…</p>
        ) : usersError ? (
          <div className="error">{usersError}</div>
        ) : users.length === 0 ? (
          <p className="muted">No users found.</p>
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
              {users.map((user) => (
                <tr key={user.id}>
                  <td>{user.name}</td>
                  <td>{user.email}</td>
                  <td>
                    <select
                      value={user.role || 'customer'}
                      disabled={updatingUserId === user.id}
                      onChange={(e) => void updateUserRole(user.id, e.target.value as UserRole)}
                    >
                      <option value="god">God</option>
                      <option value="admin">Admin</option>
                      <option value="customer">Customer</option>
                    </select>
                    <div className="muted" style={{ marginTop: 4 }}>{roleLabel((user.role || 'customer') as UserRole)}</div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </section>
  );
}
