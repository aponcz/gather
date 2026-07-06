import { useEffect, useRef } from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export function OAuthCallback() {
  const location = useLocation();
  const { completeOAuthSignIn } = useAuth();
  const processedRef = useRef(false);

  useEffect(() => {
    if (processedRef.current) return;

    const query = new URLSearchParams(location.search);
    const token = query.get('token');
    if (!token) return;

    processedRef.current = true;
    void completeOAuthSignIn(token)
      .then(() => {
        // Delay to allow localStorage to flush and JS execution to complete
        setTimeout(() => {
          window.location.replace('/');
        }, 200);
      })
      .catch(() => {
        window.location.replace('/login');
      });
  }, [completeOAuthSignIn, location.search]);

  const query = new URLSearchParams(location.search);
  const token = query.get('token');

  if (!token) {
    return <Navigate to="/login" replace />;
  }

  return <div className="center-card">Completing sign-in…</div>;
}
