import React, { useState } from 'react';
import { gql, useMutation } from '@apollo/client';
import { useNavigate, useLocation } from 'react-router-dom';
import GoogleLoginButton from '@/components/GoogleLoginButton';
import { Card, CardHeader, CardTitle, CardContent, CardFooter } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { APP_TOKEN_KEY } from '@/lib/constants';
import { validatePassword } from '@/lib/utils';
import { Link } from 'react-router-dom';

const SIGN_UP_MUTATION = gql`
  mutation SignUp($input: SignUpInput!) {
    signUp(input: $input) {
      user {
        id
        email
        name
      }
      token
      errors
      emailConfirmationRequired
    }
  }
`;

const SignUpPage: React.FC = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const redirectParam = new URLSearchParams(location.search).get('redirect');
  const redirectUrl = redirectParam || '/';
  const signInLink = redirectParam
    ? `/sign_in?redirect=${encodeURIComponent(redirectParam)}`
    : '/sign_in';

  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [errorMessage, setErrorMessage] = useState('');

  const [signUp, { loading, error }] = useMutation(SIGN_UP_MUTATION);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!validatePassword(password)) {
      setErrorMessage(
        'Password must be at least 8 characters long and contain a special character'
      );
      return;
    }

    setErrorMessage('');

    const { data } = await signUp({
      variables: { input: { name, email, password } },
    });

    const result = data?.signUp;

    if (result?.emailConfirmationRequired) {
      navigate(`/verify_email?email=${encodeURIComponent(email)}`);
      return;
    }

    if (result?.token) {
      localStorage.setItem(APP_TOKEN_KEY, result.token);
      navigate(redirectUrl);
      return;
    }

    if (result?.errors?.length) {
      setErrorMessage(result.errors[0]);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-100">
      <Card className="max-w-md w-full p-6">
        <CardHeader className="mb-4">
          <CardTitle className="font-heading text-center text-2xl font-bold">Sign Up</CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <Label htmlFor="name" className="font-body m-1">
                Name
              </Label>
              <Input
                id="name"
                type="text"
                value={name}
                onChange={e => setName(e.target.value)}
                placeholder="Your Name"
                required
              />
            </div>
            <div>
              <Label htmlFor="email" className="font-body m-1">
                Email
              </Label>
              <Input
                id="email"
                type="email"
                value={email}
                onChange={e => setEmail(e.target.value)}
                placeholder="name@example.com"
                required
              />
            </div>
            <div>
              <Label htmlFor="password" className="font-body m-1">
                Password
              </Label>
              <Input
                id="password"
                type="password"
                value={password}
                onChange={e => setPassword(e.target.value)}
                placeholder="********"
                required
              />
              {errorMessage && <p className="text-red-500 text-sm mt-2">{errorMessage}</p>}
            </div>
            <Button type="submit" disabled={loading} className="w-full font-body">
              Sign Up
            </Button>
            <GoogleLoginButton />
          </form>
        </CardContent>
        <CardFooter className="flex justify-center mt-4">
          <Link to={signInLink} className="font-body text-blue-500 hover:underline">
            Already have an account? Log In
          </Link>
        </CardFooter>
        {error && (
          <p className="mt-4 text-red-500 text-center">Something went wrong. Please try again.</p>
        )}
      </Card>
    </div>
  );
};

export default SignUpPage;
