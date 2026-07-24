import React, { useState } from 'react';
import { Link, useNavigate, useLocation } from 'react-router-dom';
import GoogleLoginButton from '@/components/GoogleLoginButton';
import { APP_TOKEN_KEY } from '@/lib/constants';
import { Button } from '@/components/ui/button';
import { Card, CardHeader, CardContent, CardFooter, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { gql, useMutation } from '@apollo/client';
import { jwtDecode } from 'jwt-decode';
import { useAuth } from '@/contexts/AuthContext';
import { JWTPayload } from '@/types/app';

const SIGN_IN_MUTATION = gql`
  mutation SignIn($input: SignInInput!) {
    signIn(input: $input) {
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

const SigninPage: React.FC = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const searchParams = new URLSearchParams(location.search);
  const redirectParam = searchParams.get('redirect');
  const redirectUrl = redirectParam || '/';
  const signUpLink = redirectParam
    ? `/sign_up?redirect=${encodeURIComponent(redirectParam)}`
    : '/sign_up';

  const { setUser } = useAuth();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [serverErrors, setServerErrors] = useState<string[]>([]);

  const [signIn, { loading }] = useMutation(SIGN_IN_MUTATION);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setServerErrors([]);

    const { data } = await signIn({
      variables: { input: { email, password } },
    });

    const result = data?.signIn;
    if (result?.emailConfirmationRequired) {
      navigate(`/verify_email?email=${encodeURIComponent(email)}`);
      return;
    }

    if (result?.token) {
      localStorage.setItem(APP_TOKEN_KEY, result.token);
      const decodedUser: JWTPayload = jwtDecode<JWTPayload>(result.token);
      setUser(decodedUser);
      navigate(redirectUrl);
    } else if (result?.errors?.length) {
      setServerErrors(result.errors);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-100">
      <Card className="max-w-md w-full p-6">
        <CardHeader className="mb-4">
          <CardTitle className="font-heading text-center text-2xl font-bold">Sign In</CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
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
            </div>
            <Button type="submit" disabled={loading} className="w-full font-body">
              Sign In
            </Button>
            <GoogleLoginButton />
          </form>
        </CardContent>
        <CardFooter className="flex justify-between mt-4">
          <Link to={signUpLink} className="font-body text-blue-500 hover:underline">
            Sign Up
          </Link>
          <Link to="/forgot_password" className="font-body text-blue-500 hover:underline">
            Forgot Password?
          </Link>
        </CardFooter>
        {serverErrors.length > 0 && (
          <div className="mt-4 text-red-500 text-sm text-center space-y-1">
            {serverErrors.map((err, i) => (
              <div key={i}>{err}</div>
            ))}
          </div>
        )}
      </Card>
    </div>
  );
};

export default SigninPage;
