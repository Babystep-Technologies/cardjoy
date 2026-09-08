/**
 * `/buy_postage/cancel` — they backed out of Stripe.
 *
 * Nothing was charged, and — the part that matters — nothing was lost either.
 * The send flow's recipient selection is still in `sessionStorage`, so this page
 * hands them back to exactly where they were rather than to a generic profile
 * page that would make them start over for having second thoughts.
 */
import React from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { XCircle } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { clearPostageCheckout } from '@/lib/postage';
import { clearPostageReturnTo, readPostageReturnTo } from '@/pages/HolidayCard/Send/state';

const BuyPostageCancel: React.FC = () => {
  const navigate = useNavigate();
  const [returnTo] = React.useState(() => readPostageReturnTo());

  // No money moved, so there is no webhook to wait for. Dropping the note here
  // stops a later success page from comparing against a balance recorded for a
  // top-up that never happened.
  React.useEffect(() => {
    clearPostageCheckout();
  }, []);

  const handleReturn = () => {
    clearPostageReturnTo();
    navigate(returnTo ?? '/postage');
  };

  return (
    <div className="flex min-h-[calc(100vh-4rem)] items-center justify-center px-4 py-20">
      <div className="w-full max-w-xl space-y-6 text-center">
        <XCircle className="mx-auto h-16 w-16 text-red-500" strokeWidth={1.5} />
        <h1 className="text-3xl font-bold text-gray-900">No postage added</h1>
        <p className="text-gray-600">
          Your payment wasn&apos;t completed and you haven&apos;t been charged.
        </p>

        {returnTo ? (
          <>
            <Button onClick={handleReturn}>Back to your card</Button>
            <p className="text-sm text-gray-500">
              Your recipients are still selected — you can add postage whenever you&apos;re ready.
            </p>
          </>
        ) : (
          <Link
            to="/postage"
            className="inline-block rounded-xl bg-black px-6 py-3 font-medium text-white transition-colors hover:bg-gray-800"
          >
            Try again
          </Link>
        )}
      </div>
    </div>
  );
};

export default BuyPostageCancel;
