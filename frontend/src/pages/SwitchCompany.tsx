import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export function SwitchCompany() {
  const { company, companies, switchCompany } = useAuth();
  const navigate = useNavigate();
  const [switching, setSwitching] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSwitchCompany(nextCompanyId: string) {
    if (!nextCompanyId || nextCompanyId === company?.id) return;
    setSwitching(true);
    setError(null);
    try {
      await switchCompany(nextCompanyId);
      navigate('/');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to switch company');
    } finally {
      setSwitching(false);
    }
  }

  return (
    <section>
      <div className="page-header">
        <div>
          <h1>Switch Company</h1>
          <p className="muted">Select a company to switch to.</p>
        </div>
      </div>
      {error && <div className="error">{error}</div>}
      {companies.length === 0 ? (
        <div className="card">
          <p className="muted">No companies available.</p>
        </div>
      ) : (
        <div className="card table-card">
          <table>
            <thead>
              <tr>
                <th>Company Name</th>
                <th>Subdomain</th>
                <th>Status</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {companies.map((c) => (
                <tr key={c.id}>
                  <td>{c.name}</td>
                  <td>{c.subdomain}</td>
                  <td>
                    {c.id === company?.id && <span style={{ color: '#10b981' }}>✓ Active</span>}
                  </td>
                  <td>
                    {c.id === company?.id ? (
                      <span className="muted">Current</span>
                    ) : (
                      <button
                        className="primary button"
                        onClick={() => handleSwitchCompany(c.id)}
                        disabled={switching}
                      >
                        {switching ? 'Switching...' : 'Switch'}
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}
