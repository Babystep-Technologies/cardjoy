import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '@/contexts/AuthContext';
import withAuth from '@/lib/with-auth';
import { gql, useMutation, useQuery } from '@apollo/client';
import { Card, CardTitle, CardHeader, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { CREDIT_PLANS } from '@/lib/constants';
import { slackInstallUrl } from '@/lib/slack';
import LoadingScreen from '@/components/Loading';
import ErrorScreen from '@/components/Error';
import { LoaderCircle } from 'lucide-react';
import { Toaster } from 'sonner';

const CREATE_STRIPE_CHECKOUT_SESSION = gql`
  mutation CreateStripeCheckoutSession($input: CreateStripeCheckoutSessionInput!) {
    createStripeCheckoutSession(input: $input) {
      checkoutUrl
      error
    }
  }
`;

export const GET_USER_PROFILE = gql`
  query GetUserProfile($id: ID!) {
    user(id: $id) {
      id
      name
      email
      creditBalance
    }
  }
`;

function Profile() {
  const navigate = useNavigate();
  const { user, logout, loading } = useAuth();
  const [showPlans, setShowPlans] = useState(false);
  const [stripeLoading, setStripeLoading] = useState(false);

  const {
    data: userData,
    loading: profileLoading,
    error: userError,
  } = useQuery(GET_USER_PROFILE, {
    fetchPolicy: 'network-only',
    skip: !user?.user_id,
    variables: { id: user?.user_id },
  });

  const [createSession] = useMutation(CREATE_STRIPE_CHECKOUT_SESSION);

  const handleBuyCredits = async (priceId: string) => {
    setStripeLoading(true);
    try {
      const { data } = await createSession({ variables: { input: { priceId } } });
      const url = data?.createStripeCheckoutSession?.checkoutUrl;
      if (url) {
        window.location.href = url;
      } else {
        setStripeLoading(false);
        return <ErrorScreen details="Stripe Checkout Failed" />;
      }
    } catch (error) {
      console.error('Stripe checkout failed:', (error as Error).message);
      setStripeLoading(false);
    }
  };

  const handleLogout = () => {
    logout();
    navigate('/');
  };

  if (loading || profileLoading) return <LoadingScreen />;
  if (userError) return <ErrorScreen details="Failed to load user profile" />;

  return (
    <>
      <Toaster />
      {stripeLoading && (
        <div className="fixed inset-0 z-50 bg-white bg-opacity-80 flex flex-col items-center justify-center space-y-4">
          <LoaderCircle className="animate-spin w-12 h-12 text-black" />
          <p className="text-black text-lg font-medium">Redirecting to checkout...</p>
        </div>
      )}

      <div className="flex flex-col flex-grow min-h-[calc(100vh-4rem)] p-4">
        <div className="w-full max-w-5xl mx-auto px-4 py-6 mt-8">
          <Card className="shadow-md rounded-xl">
            <CardHeader className="pb-2">
              <h2 className="text-2xl font-bold text-center">Your Profile</h2>
            </CardHeader>
            <CardContent className="space-y-6">
              <div className="space-y-1">
                <p className="text-sm text-gray-500">Name</p>
                <p className="text-lg font-medium text-black">{userData?.user?.name ?? '—'}</p>
              </div>
              <div className="space-y-1">
                <p className="text-sm text-gray-500">Email</p>
                <p className="text-lg font-medium text-black">{userData?.user?.email ?? '—'}</p>
              </div>

              <div className="space-y-1">
                <Button onClick={handleLogout} variant="destructive" className="w-full sm:w-auto">
                  Log Out
                </Button>
              </div>

              <hr />

              <div className="space-y-2">
                <p className="text-sm text-gray-500">Available Credits</p>
                <p className="text-lg font-bold text-black">
                  {userData?.user?.creditBalance || 0} Credits
                </p>
                <div className="flex flex-col sm:flex-row sm:items-center gap-3">
                  <Button onClick={() => setShowPlans(!showPlans)} className="w-full sm:w-auto">
                    Buy More Credits
                  </Button>
                  <Button
                    variant="outline"
                    onClick={() => navigate('/redeem')}
                    className="w-full sm:w-auto"
                  >
                    Redeem Promo Code
                  </Button>
                </div>
              </div>

              {showPlans && (
                <div className="grid gap-6 md:grid-cols-3">
                  {CREDIT_PLANS.map(plan => (
                    <Card
                      key={plan.title}
                      onClick={() => handleBuyCredits(plan.priceId)}
                      className={`
                        relative overflow-hidden transition-transform hover:scale-105 cursor-pointer
                        ${plan.highlight ? 'border-2 border-black shadow-lg bg-white' : 'shadow-sm'}
                      `}
                    >
                      {plan.highlight && (
                        <div className="absolute top-0 right-0 bg-black text-white text-xs font-bold px-3 py-1 rounded-bl-md">
                          Best Value
                        </div>
                      )}
                      <CardHeader className="pb-0">
                        <CardTitle className="text-xl font-semibold">{plan.title}</CardTitle>
                      </CardHeader>
                      <CardContent className="space-y-2 pt-2">
                        <p className="text-3xl font-bold text-black">{plan.price}</p>
                        <p className="text-sm text-gray-700">{plan.credits}</p>
                        <p className="text-sm text-gray-500">{plan.use}</p>
                      </CardContent>
                    </Card>
                  ))}
                </div>
              )}

              <hr />

              <div className="space-y-2">
                <p className="text-sm text-gray-500">Slack Integration</p>
                <p className="text-sm text-gray-700">
                  Install the Cardjoy Slack app to create cards directly from Slack using{' '}
                  <code className="bg-gray-100 px-1 rounded">/cardjoy create for &lt;name&gt;</code>
                </p>
                <a href={slackInstallUrl()}>
                  <img
                    alt="Add to Slack"
                    height="40"
                    width="139"
                    src="https://platform.slack-edge.com/img/add_to_slack.png"
                    srcSet="https://platform.slack-edge.com/img/add_to_slack.png 1x, https://platform.slack-edge.com/img/add_to_slack@2x.png 2x"
                  />
                </a>
              </div>

              <div className="flex flex-col items-center text-center space-y-4 py-6 border-t border-gray-200 mt-8">
                <p className="text-xl font-semibold text-black">need help with something?</p>
                <Button
                  onClick={() => navigate('/support?new=1')}
                  className="px-6 py-2 text-white bg-black hover:bg-gray-900 transition-colors rounded-md"
                >
                  Contact Us
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    </>
  );
}

export default withAuth(Profile);
