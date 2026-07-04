import React, { useEffect, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { gql, useMutation } from '@apollo/client';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Card, CardHeader, CardContent, CardTitle } from '@/components/ui/card';
import { APP_TOKEN_KEY } from '@/lib/constants';
import { jwtDecode } from 'jwt-decode';
import { useAuth } from '@/contexts/AuthContext';
import { JWTPayload } from '@/types/app';

const CONFIRM_EMAIL_MUTATION = gql`
  mutation ConfirmEmail($input: ConfirmEmailInput!) {
    confirmEmail(input: $input) {
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

const RESEND_CONFIRMATION_MUTATION = gql`
  mutation ResendConfirmationCode($input: ResendConfirmationCodeInput!) {
    resendConfirmationCode(input: $input) {
      success
      errors
    }
  }
`;

const VerifyEmail: React.FC = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const searchParams = new URLSearchParams(location.search);
  const email = searchParams.get('email');

  const { setUser } = useAuth();

  const [code, setCode] = useState('');
  const [message, setMessage] = useState<string | null>(null);
  const [messageType, setMessageType] = useState<'success' | 'error' | null>(null);

  const [confirmEmail, { loading }] = useMutation(CONFIRM_EMAIL_MUTATION);
  const [resendCode, { loading: resendLoading }] = useMutation(RESEND_CONFIRMATION_MUTATION);

  useEffect(() => {
    if (!email) {
      setMessage('Missing email. Please go back to sign in.');
      setMessageType('error');
    }
  }, [email]);

  const handleConfirm = async (e: React.FormEvent) => {
    e.preventDefault();
    setMessage(null);

    const { data } = await confirmEmail({ variables: { input: { email, code } } });

    const result = data?.confirmEmail;
    if (result?.token) {
      localStorage.setItem(APP_TOKEN_KEY, result.token);
      const decoded: JWTPayload = jwtDecode(result.token);
      setUser(decoded);
      navigate('/dashboard');
    } else {
      setMessage(result?.errors?.[0] || 'Failed to confirm email.');
      setMessageType('error');
    }
  };

  const handleResend = async () => {
    if (!email) return;

    setMessage(null);
    const { data } = await resendCode({ variables: { input: { email } } });

    if (data?.resendConfirmationCode?.success) {
      setMessage('A new code has been sent to your email.');
      setMessageType('success');
    } else {
      setMessage('There was an error generating a new code.');
      setMessageType('error');
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-100 px-4">
      <Card className="w-full max-w-md h-1/2 flex flex-col justify-center p-6">
        <CardHeader className="text-center">
          <CardTitle className="text-2xl font-bold">Verify Your Email</CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleConfirm} className="space-y-4">
            <div className="flex flex-col space-y-2">
              <Label htmlFor="code" className="text-base mt-2">
                6-digit Code
              </Label>
              <Input
                id="code"
                type="text"
                inputMode="numeric"
                maxLength={6}
                value={code}
                onChange={e => setCode(e.target.value)}
                placeholder="123456"
                required
              />
            </div>

            <Button type="submit" className="w-full mt-2" disabled={loading}>
              Confirm Email
            </Button>
          </form>

          <Button
            variant="outline"
            className="w-full mt-4"
            disabled={resendLoading}
            onClick={handleResend}
          >
            Resend Code
          </Button>

          {message && (
            <p
              className={`mt-4 text-sm text-center ${
                messageType === 'success' ? 'text-green-600' : 'text-red-500'
              }`}
            >
              {message}
            </p>
          )}
        </CardContent>
      </Card>
    </div>
  );
};

export default VerifyEmail;
