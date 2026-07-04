import React, { useEffect, useState } from 'react';
import { useLocation } from 'react-router-dom';
import { useMutation, useQuery, gql } from '@apollo/client';
import { CREDIT_PLANS } from '@/lib/constants';
import withAuth from '@/lib/with-auth';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import * as motion from 'motion/react-client';
import { AlertCircle, GiftIcon } from 'lucide-react';
import ErrorScreen from '@/components/Error';
import { useAuth } from '@/contexts/AuthContext';

const CREATE_STRIPE_CHECKOUT_SESSION = gql`
  mutation CreateStripeCheckoutSession($input: CreateStripeCheckoutSessionInput!) {
    createStripeCheckoutSession(input: $input) {
      checkoutUrl
      error
    }
  }
`;

const GET_PROMO_CODE = gql`
  query GetUserPromoCode($userId: ID!) {
    userPromoCode(userId: $userId) {
      code
    }
  }
`;

const BuyCredits: React.FC = () => {
  const location = useLocation();
  const searchParams = new URLSearchParams(location.search);
  const reason = searchParams.get('reason');
  const { user } = useAuth();

  const [selectedPlan, setSelectedPlan] = useState(CREDIT_PLANS[0]);
  const [createSession, { loading }] = useMutation(CREATE_STRIPE_CHECKOUT_SESSION);
  const { data: promoData, loading: promoLoading } = useQuery(GET_PROMO_CODE, {
    variables: { userId: user?.user_id },
    skip: !user?.user_id,
  });
  const [showPromoModal, setShowPromoModal] = useState(false);

  useEffect(() => {
    if (!promoLoading && promoData?.userPromoCode?.code) {
      setShowPromoModal(true);
    }
  }, [promoLoading, promoData]);

  const message =
    reason === 'insufficient_balance'
      ? 'You don’t have enough credits to create a card.'
      : reason === 'promo'
        ? 'Take advantage of this special offer and get extra credits!'
        : 'Buy credits to create and send cards.';

  const handleCheckout = async () => {
    const { data } = await createSession({
      variables: { input: { priceId: selectedPlan.priceId } },
    });

    const url = data?.createStripeCheckoutSession?.checkoutUrl;
    if (url) {
      window.location.href = url;
    } else {
      return <ErrorScreen details="Stripe Checkout Failed" />;
    }
  };

  return (
    <div className="min-h-screen flex flex-col items-center justify-start px-4 pt-16 pb-12">
      {showPromoModal && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center px-4">
          <div className="bg-white dark:bg-zinc-900 w-full max-w-md rounded-2xl shadow-xl p-6 text-center space-y-4">
            <div className="flex justify-center text-brand-yellow">
              <GiftIcon className="w-12 h-12" />
            </div>
            <h2 className="text-2xl font-bold">Our Gift to You</h2>
            <p className="text-gray-600 dark:text-gray-300">
              You have a special promo code. You can redeem it for extra credits.
            </p>
            <div className="bg-gray-100 dark:bg-zinc-800 text-xl font-mono py-3 rounded-lg text-black">
              {promoData.userPromoCode.code}
            </div>
            <div className="flex flex-col md:flex-row md:flex-wrap justify-center items-center gap-3 mt-4 w-full">
              <Button
                className="w-full md:w-1/2"
                onClick={() => {
                  window.location.href = `/redeem?code=${promoData.userPromoCode.code}`;
                }}
              >
                Redeem Promo
              </Button>
              <Button
                variant="outline"
                className="w-full md:w-1/2"
                onClick={() => setShowPromoModal(false)}
              >
                Skip
              </Button>
            </div>
          </div>
        </div>
      )}

      <div className="max-w-4xl w-full space-y-8 text-center">
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.4 }}
        >
          <div className="flex justify-center items-center gap-2 text-sm text-red-600 font-medium">
            <AlertCircle size={20} />
            {message}
          </div>
          <h1 className="text-4xl font-bold text-black mt-2">Buy Credits</h1>
          <p className="text-gray-600 mt-2">
            Each card costs <span className="font-semibold text-black">1 credit</span>. Choose a
            plan below to continue.
          </p>
        </motion.div>

        <div className="grid gap-6 md:grid-cols-3">
          {CREDIT_PLANS.map(plan => (
            <Card
              key={plan.title}
              onClick={() => setSelectedPlan(plan)}
              className={`
                relative overflow-hidden transition-transform hover:scale-105 cursor-pointer
                ${
                  selectedPlan.title === plan.title
                    ? 'border-2 border-black shadow-lg bg-white scale-[1.02]'
                    : 'shadow-sm'
                }
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

        <motion.div
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2, duration: 0.4 }}
        >
          <Button
            disabled={loading}
            onClick={handleCheckout}
            className="mt-8 w-full md:w-auto px-10 py-6 text-lg font-semibold bg-black text-white rounded-xl transition-transform transform hover:scale-105 hover:bg-gray-900 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? 'Redirecting...' : `Buy ${selectedPlan.credits}`}
          </Button>

          <p className="mt-6 mb-2 text-sm text-gray-400">or</p>

          <Button
            variant="outline"
            className="px-6 py-6 text-sm bg-white font-medium text-gray-600 border-gray-300 hover:text-black hover:border-black transition"
          >
            <a href="/redeem">Redeem Promo Code</a>
          </Button>
        </motion.div>
      </div>
    </div>
  );
};

export default withAuth(BuyCredits);
