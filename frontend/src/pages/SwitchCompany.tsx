import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowRight, Building2, Check, Globe2, Repeat2, Sparkles } from 'lucide-react';
import { useAuth } from '../context/AuthContext';

export function SwitchCompany() {
  const { company, companies, switchCompany } = useAuth();
  const navigate = useNavigate();
  const [switchingCompanyId, setSwitchingCompanyId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function handleSwitchCompany(nextCompanyId: string) {
    if (!nextCompanyId || nextCompanyId === company?.id) return;
    setSwitchingCompanyId(nextCompanyId);
    setError(null);
    try {
      await switchCompany(nextCompanyId);
      navigate('/');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to switch company');
    } finally {
      setSwitchingCompanyId(null);
    }
  }

  return (
    <section className="workspace-page switch-company-page">
      <div className="workspace-orb" />
      <header className="workspace-hero">
        <div><div className="marketing-eyebrow"><Sparkles size={15} /> Your workspaces</div><h1>Choose where<br /><span>you want to work.</span></h1><p>Move between company workspaces while keeping every team, client, and document request separate.</p></div>
        <div className="workspace-hero-icon"><Repeat2 size={31} /></div>
      </header>

      {error && <div className="error switch-company-error" role="alert">{error}</div>}
      {companies.length === 0 ? (
        <div className="workspace-panel switch-company-empty"><div><Building2 size={25} /></div><h2>No companies available</h2><p>Your account is not connected to a company workspace yet.</p></div>
      ) : (
        <div className="switch-company-panel workspace-panel">
          <div className="workspace-panel-heading"><div><span>Available companies</span><h2>Select a workspace</h2></div><p>{companies.length} {companies.length === 1 ? 'workspace' : 'workspaces'} available</p></div>
          <div className="switch-company-grid">
            {companies.map((availableCompany) => {
              const active = availableCompany.id === company?.id;
              const switching = switchingCompanyId === availableCompany.id;
              return <article className={active ? 'switch-company-card active' : 'switch-company-card'} key={availableCompany.id}>
                <div className="switch-company-card-top">
                  <div className="switch-company-mark"><Building2 size={22} /></div>
                  {active && <span className="switch-company-active"><Check size={13} /> Active</span>}
                </div>
                <div className="switch-company-copy"><h3>{availableCompany.name}</h3>{availableCompany.subdomain ? <p><Globe2 size={14} /> {availableCompany.subdomain}</p> : <p><Globe2 size={14} /> No subdomain configured</p>}</div>
                {active ? <div className="switch-company-current"><Check size={15} /> Current workspace</div> : <button type="button" onClick={() => void handleSwitchCompany(availableCompany.id)} disabled={switchingCompanyId !== null}><span>{switching ? 'Switching…' : 'Open workspace'}</span><ArrowRight size={16} /></button>}
              </article>;
            })}
          </div>
        </div>
      )}
    </section>
  );
}
