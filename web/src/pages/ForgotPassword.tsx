import React, { useState } from 'react';
import { gql, useMutation } from '@apollo/client';
import { Card, CardHeader, CardTitle, CardContent, CardFooter } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Link } from 'react-router-dom';

const SEND_PASSWORD_RESET_MUTATION = gql`
  mutation SendPasswordReset($input: SendPasswordResetInput!) {
    sendPasswordReset(input: $input) {
      success
    }
  }
`;

const ForgotPassword: React.FC = () => {
  const [email, setEmail] = useState('');
  const [successMessage, setSuccessMessage] = useState('');
  const [errorMessage, setErrorMessage] = useState('');
  const [sendPasswordReset, { loading, error }] = useMutation(SEND_PASSWORD_RESET_MUTATION);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSuccessMessage('');
    setErrorMessage('');
    const { data } = await sendPasswordReset({ variables: { input: { email } } });
    if (data?.sendPasswordReset.success) {
      setSuccessMessage('A reset link has been sent to your email.');
    } else {
      setErrorMessage('Error sending reset link.');
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-100">
      <Card className="max-w-md w-full p-6">
        <CardHeader className="mb-4">
          <CardTitle className="text-center text-2xl font-bold">Forgot Password</CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <Label htmlFor="email">Email</Label>
              <Input
                id="email"
                type="email"
                value={email}
                onChange={e => setEmail(e.target.value)}
                placeholder="name@example.com"
              />
            </div>
            <Button type="submit" disabled={loading} className="w-full">
              Reset Password
            </Button>
          </form>
          {successMessage && <p className="text-green-500 mt-4 text-center">{successMessage}</p>}
          {errorMessage && <p className="text-red-500 mt-4 text-center">{errorMessage}</p>}
        </CardContent>
        <CardFooter className="flex justify-center mt-4">
          <Link to="/sign_in" className="text-blue-500 hover:underline">
            Back to Login
          </Link>
        </CardFooter>
        {error && <p className="mt-4 text-red-500 text-center">Error resetting password</p>}
      </Card>
    </div>
  );
};

export default ForgotPassword;
