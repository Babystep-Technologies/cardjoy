import { jwtDecode } from 'jwt-decode';
import { JWTPayload } from '@/types/app';

/**
 * Decode an app JWT, returning its payload only when the token is well-formed
 * and still valid. Anything else (garbage, a non-JWT, an expired token) yields
 * null so callers can treat it as "not signed in".
 */
export const decodeValidToken = (token: string | null): JWTPayload | null => {
  if (!token) return null;

  try {
    const decoded = jwtDecode<JWTPayload>(token);
    return decoded.exp * 1000 > Date.now() ? decoded : null;
  } catch {
    return null;
  }
};

/** Query string with any `token` param removed, including the leading `?`. */
export const searchWithoutToken = (search: string): string => {
  const params = new URLSearchParams(search);
  params.delete('token');
  const rest = params.toString();
  return rest ? `?${rest}` : '';
};
