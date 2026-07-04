import { createContext, useContext, useEffect, useState } from 'react';
import { jwtDecode } from 'jwt-decode';
import { APP_TOKEN_KEY } from '@/lib/constants';
import { JWTPayload } from '@/types/app';

interface AuthContextType {
  user: JWTPayload | null;
  setUser: (user: JWTPayload | null) => void;
  logout: () => void;
  loading: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider = ({ children }: { children: React.ReactNode }) => {
  const [user, setUser] = useState<JWTPayload | null>(null);
  const [loading, setLoading] = useState(true);

  const clearAuth = () => {
    localStorage.removeItem(APP_TOKEN_KEY);
    setUser(null);
  };

  const logout = () => {
    clearAuth();
    window.location.replace('/sign_in');
  };

  useEffect(() => {
    const token = localStorage.getItem(APP_TOKEN_KEY);

    if (!token) {
      setUser(null);
      setLoading(false);
      return;
    }

    try {
      const decoded = jwtDecode<JWTPayload>(token);

      // Check if token already expired - just clear auth without redirecting
      // This allows users to stay on public pages like invitation views
      if (decoded.exp * 1000 < Date.now()) {
        console.warn('Token expired, clearing auth');
        clearAuth();
      } else {
        setUser(decoded);
      }
    } catch (error) {
      console.error('Token decoding error:', error);
      clearAuth();
    } finally {
      setLoading(false);
    }
  }, []);

  return (
    <AuthContext.Provider value={{ user, setUser, logout, loading }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
