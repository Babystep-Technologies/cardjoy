import { useEffect, useState } from 'react';
import { useMutation, gql, ApolloError } from '@apollo/client';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Gift, CheckCircle, XCircle, Sparkles } from 'lucide-react';
import withAuth from '@/lib/with-auth';
import * as motion from 'motion/react-client';
import { Link, useSearchParams } from 'react-router-dom';

const REDEEM_PROMO_CODE = gql`
  mutation RedeemPromoCode($input: RedeemPromoCodeInput!) {
    redeemPromoCode(input: $input) {
      success
      creditAmount
      error
    }
  }
`;

const RedeemPromo: React.FC = () => {
  const [searchParams] = useSearchParams();
  const [code, setCode] = useState('');
  const [status, setStatus] = useState<'idle' | 'success' | 'error'>('idle');
  const [message, setMessage] = useState<string | null>(null);

  const [redeemCode, { loading }] = useMutation(REDEEM_PROMO_CODE);

  useEffect(() => {
    const prefillCode = searchParams.get('code');
    if (prefillCode) {
      setCode(prefillCode);
    }
  }, [searchParams]);

  const handleRedeem = async () => {
    setStatus('idle');
    setMessage(null);

    try {
      const { data } = await redeemCode({ variables: { input: { code } } });
      const result = data?.redeemPromoCode;

      if (result.success) {
        setStatus('success');
        setMessage(`Successfully redeemed ${result.creditAmount} credits!`);
      } else {
        setStatus('error');
        setMessage(result.error || 'Something went wrong.');
      }
    } catch (error) {
      setStatus('error');
      const err = error as ApolloError;
      setMessage(err.message || 'Unexpected error occurred.');
    }
  };

  return (
    <div className="min-h-screen flex flex-col items-center justify-start px-4 pt-20 pb-12">
      <motion.div
        className="w-full max-w-md space-y-8 text-center"
        initial={{ opacity: 0, y: 12 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
      >
        <div className="flex justify-center">
          <Gift className="w-10 h-10 text-pink-500" />
        </div>

        <h1 className="text-3xl font-bold text-black flex items-center justify-center gap-2">
          Redeem Promo Code
          <Sparkles className="w-6 h-6 text-yellow-400" />
        </h1>
        <p className="text-gray-600">
          Enter your promo code below to receive bonus credits to your CardJoy account.
        </p>

        <div className="flex flex-col sm:flex-row items-center gap-3">
          <Input
            value={code}
            onChange={e => setCode(e.target.value)}
            placeholder="Enter promo code"
            className="bg-white text-black text-lg px-6 py-5 w-full rounded-xl"
          />
          <Button
            onClick={handleRedeem}
            disabled={loading || code.trim() === ''}
            className="px-8 py-5 text-lg font-semibold w-full sm:w-auto rounded-xl"
          >
            {loading ? 'Redeeming...' : 'Redeem'}
          </Button>
        </div>

        {status === 'success' && (
          <div className="flex flex-col items-center justify-center text-green-600 text-sm font-medium gap-2">
            <div className="flex items-center gap-2">
              <CheckCircle size={20} />
              {message}
            </div>
            <div className="mt-2 text-black text-sm">
              <span>
                <Link to="/dashboard" className="text-blue-600 underline hover:text-blue-800">
                  Go back to home
                </Link>{' '}
                or{' '}
                <Link to="/group-card/new" className="text-blue-600 underline hover:text-blue-800">
                  start creating a card
                </Link>
                .
              </span>
            </div>
          </div>
        )}

        {status === 'error' && (
          <div className="flex items-center justify-center text-red-600 text-sm font-medium gap-2">
            <XCircle size={20} />
            {message}
          </div>
        )}
      </motion.div>
    </div>
  );
};

export default withAuth(RedeemPromo);
