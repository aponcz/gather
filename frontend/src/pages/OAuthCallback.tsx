import { useEffect, useRef } from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export function OAuthCallback() {
  const location = useLocation();
  const { completeOAuthSignIn } = useAuth();
  const processedRef = useRef(false);
  const tokenRef = useRef(
    new URLSearchParams(location.hash.slice(1)).get('token') ||
    new URLSearchParams(location.search).get('token')
  );

  useEffect(() => {
    if (processedRef.current) return;

    const token = tokenRef.current;
    if (!token) return;

    processedRef.current = true;
    window.history.replaceState(null, '', location.pathname);
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
  }, [completeOAuthSignIn, location.pathname]);

  const token = tokenRef.current;

  if (!token) {
    return <Navigate to="/login" replace />;
  }

  return <div className="center-card">Completing sign-in…</div>;
}
