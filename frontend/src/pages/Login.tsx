import { useState } from 'react';
import { Navigate } from 'react-router-dom';
import { ArrowRight, Check, Clock3, FileCheck2, MessageSquareText, ShieldCheck, Sparkles, UploadCloud, Users, Zap } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { getProTextAuthorizationUrl } from '../api/admin';

const features = [
  { icon: MessageSquareText, title: 'Request with clarity', copy: 'Send one organized request with every document, deadline, and detail your client needs.' },
  { icon: UploadCloud, title: 'Collect without chasing', copy: 'Give clients a simple, secure place to upload files from any device—no messy email threads.' },
  { icon: FileCheck2, title: 'Review in one place', copy: 'See what is missing, approve submissions, and keep every loan moving from a single workspace.' },
];

export function Login() {
  const { user } = useAuth();
  const [error, setError] = useState<string | null>(null);
  const [signingIn, setSigningIn] = useState(false);

  if (user) return <Navigate to="/" replace />;

  async function signInWithProText() {
    setError(null);
    setSigningIn(true);
    try {
      const result = await getProTextAuthorizationUrl();
      window.location.assign(result.authorization_url);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'OAuth sign-in failed');
      setSigningIn(false);
    }
  }

  const signInButton = (label = 'Sign in with ProText') => (
    <button className="marketing-cta" type="button" onClick={() => void signInWithProText()} disabled={signingIn}>
      <span>{signingIn ? 'Connecting…' : label}</span><ArrowRight size={18} aria-hidden="true" />
    </button>
  );

  return (
    <div className="marketing-page">
      <header className="marketing-nav">
        <a className="marketing-brand" href="#top" aria-label="ProText Gather home">
          <span className="marketing-brand-mark"><FileCheck2 size={22} /></span>
          <span>ProText <strong>Gather</strong></span>
        </a>
        <nav aria-label="Main navigation"><a href="#how-it-works">How it works</a><a href="#why-gather">Why Gather</a></nav>
        <button className="marketing-signin" type="button" onClick={() => void signInWithProText()} disabled={signingIn}>
          Sign in <ArrowRight size={16} aria-hidden="true" />
        </button>
      </header>

      <main id="top">
        <section className="marketing-hero">
          <div className="marketing-orb marketing-orb-one" /><div className="marketing-orb marketing-orb-two" />
          <div className="marketing-hero-copy">
            <div className="marketing-eyebrow"><Sparkles size={15} /> Document collection, simplified</div>
            <h1>Stop chasing documents.<br /><span>Start closing faster.</span></h1>
            <p>Gather turns scattered follow-ups into one calm, secure workflow—so your team knows what is complete, what is missing, and what comes next.</p>
            <div className="marketing-hero-actions">
              {signInButton('Open your workspace')}
              <span><ShieldCheck size={17} /> Secure sign-in through ProText</span>
            </div>
            {error && <div className="error marketing-error" role="alert">{error}</div>}
          </div>

          <div className="product-preview" aria-label="Gather product preview">
            <div className="preview-window-bar">
              <div className="preview-dots"><i /><i /><i /></div><span>Document request</span><span className="preview-secure"><ShieldCheck size={13} /> Secure</span>
            </div>
            <div className="preview-body">
              <aside className="preview-sidebar"><span className="preview-logo"><FileCheck2 size={16} /></span><i className="active" /><i /><i /><i /></aside>
              <div className="preview-content">
                <div className="preview-heading"><div><small>Rivera Home Loan</small><strong>Document collection</strong></div><span>75% complete</span></div>
                <div className="preview-progress"><i /></div>
                <div className="preview-list">
                  <div className="preview-row complete"><span><Check size={16} /></span><div><strong>Photo ID</strong><small>Received today</small></div><b>Approved</b></div>
                  <div className="preview-row complete"><span><Check size={16} /></span><div><strong>Bank statements</strong><small>2 files received</small></div><b>Approved</b></div>
                  <div className="preview-row pending"><span><Clock3 size={16} /></span><div><strong>Proof of income</strong><small>Awaiting upload</small></div><b>Pending</b></div>
                </div>
                <div className="preview-activity"><Users size={16} /><span><strong>Everyone is in sync.</strong> Updates appear here in real time.</span></div>
              </div>
            </div>
            <div className="preview-float preview-float-top"><Zap size={17} /><span><strong>3 files received</strong><small>Just now</small></span></div>
            <div className="preview-float preview-float-bottom"><Check size={17} /><span><strong>Request complete</strong><small>Ready for review</small></span></div>
          </div>
        </section>

        <section className="marketing-trust" aria-label="Benefits"><span>One link for your clients</span><i /><span>One view for your team</span><i /><span>Every document accounted for</span></section>

        <section className="marketing-features" id="how-it-works">
          <div className="marketing-section-heading"><span>How it works</span><h2>A better experience on both sides of the request.</h2><p>Less friction for clients. More visibility for your team. Everything needed to move work forward.</p></div>
          <div className="marketing-feature-grid">
            {features.map(({ icon: Icon, title, copy }, index) => (
              <article key={title} className="marketing-feature-card"><div className="feature-number">0{index + 1}</div><div className="feature-icon"><Icon size={24} /></div><h3>{title}</h3><p>{copy}</p></article>
            ))}
          </div>
        </section>

        <section className="marketing-focus" id="why-gather">
          <div><span className="marketing-kicker">Built for momentum</span><h2>Your team’s clearest path from request to complete.</h2></div>
          <div className="marketing-focus-list"><p><Check size={18} /> Live status for every document request</p><p><Check size={18} /> Secure client uploads from any device</p><p><Check size={18} /> Organized review and approval workflows</p><p><Check size={18} /> Company workspaces that stay separate</p></div>
        </section>

        <section className="marketing-bottom-cta"><div className="cta-spark"><Sparkles size={26} /></div><span>Ready when you are</span><h2>Bring every document<br />into focus.</h2><p>Your ProText workspace is one secure sign-in away.</p>{signInButton()}</section>
      </main>

      <footer className="marketing-footer">
        <div className="marketing-brand"><span className="marketing-brand-mark"><FileCheck2 size={20} /></span><span>ProText <strong>Gather</strong></span></div>
        <p>Secure document collection that keeps work moving.</p><span>© {new Date().getFullYear()} ProText</span>
      </footer>
    </div>
  );
}
