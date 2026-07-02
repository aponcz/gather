import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import * as adminApi from '../api/admin';
import { Company } from '../types';

export function ManageCompanies() {
  const [companies, setCompanies] = useState<Company[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function loadCompanies() {
      setLoading(true);
      setError(null);
      try {
        setCompanies(await adminApi.listCompanies());
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Could not load companies');
      } finally {
        setLoading(false);
      }
    }

    void loadCompanies();
  }, []);

  const uniqueCompanies = companies.filter((company, index, list) => {
    return list.findIndex((candidate) => candidate.id === company.id ||
      (candidate.name?.trim().toLowerCase() === company.name?.trim().toLowerCase() &&
        (candidate.subdomain || '').trim().toLowerCase() === (company.subdomain || '').trim().toLowerCase())) === index;
  });

  return (
    <section className="form-stack" style={{ maxWidth: 900 }}>
      <p className="muted"><Link to="/admin">Admin Dashboard</Link> / Manage Companies</p>
      <h1>Manage Companies</h1>
      <p className="muted">All companies.</p>

      <div className="card table-card">
        {loading ? (
          <p className="muted">Loading companies…</p>
        ) : error ? (
          <div className="error">{error}</div>
        ) : uniqueCompanies.length === 0 ? (
          <p className="muted">No companies found.</p>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>Subdomain</th>
                <th>Website</th>
              </tr>
            </thead>
            <tbody>
              {uniqueCompanies.map((listedCompany) => (
                <tr key={listedCompany.id}>
                  <td>{listedCompany.name}</td>
                  <td>{listedCompany.subdomain || '—'}</td>
                  <td>{listedCompany.website || '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </section>
  );
}
