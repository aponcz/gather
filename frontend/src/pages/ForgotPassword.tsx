import { useState } from "react";
import { Link, Navigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";

export default function ForgotPassword() {
  const { user } = useAuth();
  const [email, setEmail] = useState("");
  const [submitted, setSubmitted] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  if (user) return <Navigate to="/" replace />;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);

    try {
      const response = await fetch("/api/v1/auth/forgot-password", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email }),
      });

      if (response.ok) {
        setSubmitted(true);
      } else {
        const data = await response.json();
        setError(data.error || "Failed to send reset email");
      }
    } catch (err) {
      setError("An error occurred. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="auth-page">
      <form className="card auth-card" onSubmit={handleSubmit}>
        <h1>Reset your password</h1>
        <p className="muted">Enter your email address and we'll send you a link to reset your password.</p>

        {submitted ? (
          <div>
            <p style={{ color: '#2858d8', marginBottom: '20px' }}>
              ✓ If an account exists with <strong>{email}</strong>, you will receive an email with instructions to reset your password.
            </p>
            <p className="muted" style={{ fontSize: '0.9em', marginBottom: '20px' }}>Please check your email and spam folder.</p>
            <Link to="/login" className="primary" style={{ display: 'block', textAlign: 'center', padding: '11px 16px', textDecoration: 'none', color: 'white' }}>
              Back to Login
            </Link>
          </div>
        ) : (
          <>
            <label>Email
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="Enter your email"
                required
                disabled={loading}
              />
            </label>

            {error && <div className="error">{error}</div>}

            <button
              type="submit"
              className="primary"
              disabled={loading}
              style={{ width: '100%' }}
            >
              {loading ? "Sending..." : "Send Reset Email"}
            </button>

            <button type="button" className="link-button" onClick={() => window.location.href = "/login"}>
              Back to Login
            </button>
          </>
        )}
      </form>
    </div>
  );
}
