import { createContext, useContext, useEffect, useState } from 'react';
import { jwtDecode } from 'jwt-decode';
import { APP_TOKEN_KEY } from '@/lib/constants';
import { JWTPayload } from '@/types/app';

interface AuthContextType {
  admin: JWTPayload | null;
  setAdmin: (admin: JWTPayload | null) => void;
  logout: () => void;
  loading: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider = ({ children }: { children: React.ReactNode }) => {
  const [admin, setAdmin] = useState<JWTPayload | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const token = localStorage.getItem(APP_TOKEN_KEY);
    if (token) {
      try {
        const decoded = jwtDecode<JWTPayload>(token);
        setAdmin(decoded);
      } catch (error) {
        console.error('Token decoding error:', error);
        localStorage.removeItem(APP_TOKEN_KEY);
        setAdmin(null);
      }
    }
    setLoading(false);
  }, []);

  const logout = () => {
    localStorage.removeItem(APP_TOKEN_KEY);
    setAdmin(null);
  };

  return (
    <AuthContext.Provider value={{ admin, setAdmin, logout, loading }}>
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
