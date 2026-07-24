import React, { useEffect, useState } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { jwtDecode } from 'jwt-decode';
import { APP_TOKEN_KEY } from '@/lib/constants';

export default function withAuth<P extends object>(Component: React.ComponentType<P>): React.FC<P> {
  return function AuthenticatedComponent(props: P) {
    const navigate = useNavigate();
    const location = useLocation();
    const [isAuthenticated, setIsAuthenticated] = useState<boolean | null>(null);

    useEffect(() => {
      // Preserve the full target (path + query) so flows that carry state in the
      // query string survive the sign-in round-trip — e.g. /connect-slack?state=…
      const target = encodeURIComponent(`${location.pathname}${location.search}`);
      const token = localStorage.getItem(APP_TOKEN_KEY);
      if (!token) {
        navigate(`/sign_in?redirect=${target}`);
        return;
      }

      try {
        const decoded: { exp: number } = jwtDecode(token);
        if (decoded.exp * 1000 > Date.now()) {
          setIsAuthenticated(true);
        } else {
          localStorage.removeItem(APP_TOKEN_KEY);
          navigate(`/sign_in?redirect=${target}`);
        }
      } catch {
        localStorage.removeItem(APP_TOKEN_KEY);
        navigate(`/sign_in?redirect=${target}`);
      }
    }, [navigate, location.pathname, location.search]);

    if (!isAuthenticated) return null;

    return <Component {...props} />;
  };
}
