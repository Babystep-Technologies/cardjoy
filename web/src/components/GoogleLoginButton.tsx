/* eslint-disable @typescript-eslint/no-explicit-any */

import { useEffect } from 'react';
import { gql, useMutation } from '@apollo/client';
import { useNavigate } from 'react-router-dom';
import { jwtDecode } from 'jwt-decode';
import { useAuth } from '@/contexts/AuthContext';
import { APP_TOKEN_KEY } from '@/lib/constants';
import { JWTPayload } from '@/types/app';

const GOOGLE_OAUTH_MUTATION = gql`
  mutation GoogleOauthSignIn($input: GoogleOauthSignInInput!) {
    googleOauthSignIn(input: $input) {
      user {
        id
        email
        name
      }
      token
      errors
    }
  }
`;

export default function GoogleLoginButton() {
  const navigate = useNavigate();
  const { setUser } = useAuth();

  const [googleOauthSignIn, { data, loading, error }] = useMutation(GOOGLE_OAUTH_MUTATION);

  const signInErrors: string[] = data?.googleOauthSignIn?.errors ?? [];

  useEffect(() => {
    if (data?.googleOauthSignIn?.token) {
      const token = data.googleOauthSignIn.token;

      try {
        localStorage.setItem(APP_TOKEN_KEY, token);
        console.log('Token written to localStorage');
      } catch (err) {
        console.error('Failed to write token to localStorage:', err);
      }

      const decodedUser: JWTPayload = jwtDecode<JWTPayload>(token);
      setUser(decodedUser);

      const redirectUrl = new URLSearchParams(window.location.search).get('redirect') || '/';
      setTimeout(() => navigate(redirectUrl), 50);
    }
  }, [data, navigate, setUser]);

  useEffect(() => {
    const script = document.createElement('script');
    script.src = 'https://accounts.google.com/gsi/client';
    script.async = true;
    script.defer = true;
    document.body.appendChild(script);

    script.onload = () => {
      (window as any).google.accounts.id.initialize({
        client_id: import.meta.env.VITE_GOOGLE_CLIENT_ID,
        callback: (response: any) => {
          googleOauthSignIn({
            variables: {
              input: { idToken: response.credential },
            },
          });
        },
      });

      (window as any).google.accounts.id.renderButton(document.getElementById('googleSignInDiv'), {
        theme: 'outline',
        size: 'large',
      });
    };

    return () => {
      document.body.removeChild(script);
    };
  }, [googleOauthSignIn]);

  return (
    <div className="flex flex-col items-center justify-center min-h-[100px]">
      <div id="googleSignInDiv" />
      {loading && <p>Loading...</p>}
      {/* A rejected sign-in still returns data — only a token means success. */}
      {data?.googleOauthSignIn?.token && <p>Success! Redirecting...</p>}
      {signInErrors.length > 0 && <p className="text-red-500">{signInErrors.join(', ')}</p>}
      {error && <p className="text-red-500">Error with Google Sign-In</p>}
    </div>
  );
}
