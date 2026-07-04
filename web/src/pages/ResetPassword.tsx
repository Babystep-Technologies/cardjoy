import { useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { gql, useMutation, ApolloError } from '@apollo/client';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { Label } from '@/components/ui/label';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';

const RESET_PASSWORD_MUTATION = gql`
  mutation ResetPassword($input: ResetPasswordInput!) {
    resetPassword(input: $input) {
      success
      errors
    }
  }
`;

const ResetPassword: React.FC = () => {
  const location = useLocation();
  const navigate = useNavigate();
  const searchParams = new URLSearchParams(location.search);
  const token = searchParams.get('token');

  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [errorMessage, setErrorMessage] = useState('');
  const [resetPassword, { loading }] = useMutation(RESET_PASSWORD_MUTATION);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (password !== confirmPassword) {
      setErrorMessage('Passwords do not match.');
      return;
    }

    try {
      const { data } = await resetPassword({ variables: { input: { token, password } } });

      if (data?.resetPassword.success) {
        navigate('/sign_in');
      } else {
        setErrorMessage('Failed to reset password. Please try again.');
      }
    } catch (error) {
      const err = error as ApolloError;
      setErrorMessage(`An error occurred. Please try again. ${err.message}`);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-100">
      <Card className="max-w-md w-full p-6">
        <CardHeader className="mb-4">
          <CardTitle className="text-center text-2xl font-bold">Reset Password</CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <Label htmlFor="password">New Password</Label>
              <Input
                id="password"
                type="password"
                value={password}
                onChange={e => setPassword(e.target.value)}
                placeholder="********"
                required
              />
            </div>
            <div>
              <Label htmlFor="confirmPassword">Confirm Password</Label>
              <Input
                id="confirmPassword"
                type="password"
                value={confirmPassword}
                onChange={e => setConfirmPassword(e.target.value)}
                placeholder="********"
                required
              />
            </div>
            <Button type="submit" disabled={loading} className="w-full">
              {loading ? 'Resetting...' : 'Reset Password'}
            </Button>
          </form>
          {errorMessage && <p className="text-red-500 mt-4 text-center">{errorMessage}</p>}
        </CardContent>
      </Card>
    </div>
  );
};

export default ResetPassword;
