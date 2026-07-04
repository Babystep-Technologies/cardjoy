import { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { gql, useMutation } from '@apollo/client';
import withAuth from '@/lib/with-auth';
import { Card, CardContent, CardHeader } from '@/components/ui/card';
import { LoaderCircle } from 'lucide-react';

const CONNECT_SLACK_ACCOUNT = gql`
  mutation ConnectSlackAccount($input: ConnectSlackAccountInput!) {
    connectSlackAccount(input: $input) {
      success
      errors
    }
  }
`;

function ConnectSlack() {
  const [searchParams] = useSearchParams();
  const [status, setStatus] = useState<'loading' | 'success' | 'error'>('loading');
  const [errorMessage, setErrorMessage] = useState('');

  const [connectSlackAccount] = useMutation(CONNECT_SLACK_ACCOUNT);

  useEffect(() => {
    const state = searchParams.get('state');

    if (!state) {
      setStatus('error');
      setErrorMessage('Missing connection token. Please run /cardjoy in Slack again.');
      return;
    }

    connectSlackAccount({ variables: { input: { state } } })
      .then(({ data }) => {
        if (data?.connectSlackAccount?.success) {
          setStatus('success');
        } else {
          const errors = data?.connectSlackAccount?.errors ?? [];
          setStatus('error');
          setErrorMessage(errors[0] || 'Something went wrong. Please try again.');
        }
      })
      .catch(() => {
        setStatus('error');
        setErrorMessage('Something went wrong. Please try again.');
      });
  }, [connectSlackAccount, searchParams]);

  return (
    <div className="flex flex-col flex-grow min-h-[calc(100vh-4rem)] items-center justify-center p-4">
      <Card className="w-full max-w-md shadow-md rounded-xl">
        <CardHeader className="pb-2">
          <h2 className="text-2xl font-bold text-center">Connect Slack</h2>
        </CardHeader>
        <CardContent className="text-center space-y-4 py-6">
          {status === 'loading' && (
            <>
              <LoaderCircle className="animate-spin w-10 h-10 mx-auto text-black" />
              <p className="text-gray-600">Connecting your Slack account...</p>
            </>
          )}
          {status === 'success' && (
            <>
              <p className="text-4xl">🎉</p>
              <p className="text-lg font-semibold text-black">Your Slack account is connected!</p>
              <p className="text-gray-600">
                Go back to Slack and run <code className="bg-gray-100 px-1 rounded">/cardjoy</code>{' '}
                to create your first card.
              </p>
            </>
          )}
          {status === 'error' && (
            <>
              <p className="text-4xl">❌</p>
              <p className="text-lg font-semibold text-black">Connection failed</p>
              <p className="text-gray-600">{errorMessage}</p>
            </>
          )}
        </CardContent>
      </Card>
    </div>
  );
}

export default withAuth(ConnectSlack);
