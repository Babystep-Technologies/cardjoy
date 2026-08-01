import React, { useEffect, useState } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { APP_TOKEN_KEY } from '@/lib/constants';
import { decodeValidToken, searchWithoutToken } from '@/lib/auth-token';
import { useAuth } from '@/contexts/AuthContext';

export default function withAuth<P extends object>(Component: React.ComponentType<P>): React.FC<P> {
  return function AuthenticatedComponent(props: P) {
    const navigate = useNavigate();
    const location = useLocation();
    const { setUser } = useAuth();
    const [isAuthenticated, setIsAuthenticated] = useState<boolean | null>(null);

    useEffect(() => {
      const search = searchWithoutToken(location.search);
      // Preserve the full target (path + query) so flows that carry state in the
      // query string survive the sign-in round-trip — e.g. /connect-slack?state=…
      const target = encodeURIComponent(`${location.pathname}${search}`);

      if (decodeValidToken(localStorage.getItem(APP_TOKEN_KEY))) {
        setIsAuthenticated(true);
        return;
      }

      // Magic-link entry point: Slack posts links like /buy_credits?token=<jwt>
      // so a Slack-only user can reach a protected page already signed in.
      const urlToken = new URLSearchParams(location.search).get('token');
      const decoded = decodeValidToken(urlToken);
      if (decoded && urlToken) {
        localStorage.setItem(APP_TOKEN_KEY, urlToken);
        setUser(decoded);
        setIsAuthenticated(true);
        // Drop the token from the URL so it isn't left in history or shared.
        navigate(`${location.pathname}${search}`, { replace: true });
        return;
      }

      localStorage.removeItem(APP_TOKEN_KEY);
      navigate(`/sign_in?redirect=${target}`);
    }, [navigate, location.pathname, location.search, setUser]);

    if (!isAuthenticated) return null;

    return <Component {...props} />;
  };
}
