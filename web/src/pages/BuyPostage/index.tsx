/**
 * `/buy_postage` — putting money in the postage wallet.
 *
 * The send flow (#151) needs somewhere to send a user who is short, and
 * somewhere that brings them *back*. This is the minimum that does that
 * honestly: the tiers the server accepts, a Stripe Checkout redirect, and the
 * return note the send flow left. The full wallet page — balance, history,
 * spend ledger — is #152, and belongs here when it lands.
 *
 * ## Two wallets, deliberately
 *
 * `credit_balance` is whole credits and buys digital cards. `postage_balance_cents`
 * is integer US cents and buys stamps and paper. They are not interchangeable
 * and this page never mentions credits, because a user who tops up the wrong
 * one has paid for something they cannot use.
 *
 * The tiers mirror `PostageCredit::TOP_UP_TIERS_CENTS`. They are validated
 * server-side — `createStripeCheckoutSession` rejects an amount that is not on
 * that list — so this array picks from the server's price list rather than
 * naming a price of its own.
 */
import React, { useState } from 'react';
import { useMutation, useQuery, gql } from '@apollo/client';
import { Link } from 'react-router-dom';
import { Stamp, Wallet } from 'lucide-react';
import { Toaster, toast } from 'sonner';
import withAuth from '@/lib/with-auth';
import { Button } from '@/components/ui/button';
import { formatCents } from '@/lib/money';
import { cn } from '@/lib/utils';
import { readPostageReturnTo } from '@/pages/HolidayCard/Send/state';

// Keep in sync with PostageCredit::TOP_UP_TIERS_CENTS.
const TOP_UP_TIERS_CENTS = [1_000, 2_500, 5_000];

const POSTAGE_BALANCE = gql`
  query PostageBalance {
    viewer {
      id
      postageBalanceCents
    }
  }
`;

const CREATE_POSTAGE_CHECKOUT = gql`
  mutation CreatePostageCheckoutSession($topUpCents: Int!) {
    createStripeCheckoutSession(input: { product: "postage", topUpCents: $topUpCents }) {
      checkoutUrl
      error
    }
  }
`;

interface BalanceResponse {
  viewer: { id: string; postageBalanceCents: number } | null;
}

interface CheckoutResponse {
  createStripeCheckoutSession: { checkoutUrl: string | null; error: string | null };
}

const BuyPostage: React.FC = () => {
  const { data } = useQuery<BalanceResponse>(POSTAGE_BALANCE, { fetchPolicy: 'cache-and-network' });
  const [createSession, { loading }] = useMutation<CheckoutResponse>(CREATE_POSTAGE_CHECKOUT);
  const [selected, setSelected] = useState(TOP_UP_TIERS_CENTS[1]);

  const balanceCents = data?.viewer?.postageBalanceCents ?? 0;
  // Written by whatever sent the user here, so the page can offer a way back
  // without a top-up if they change their mind.
  const returnTo = readPostageReturnTo();

  const handleCheckout = async () => {
    try {
      const { data: result } = await createSession({ variables: { topUpCents: selected } });
      const url = result?.createStripeCheckoutSession?.checkoutUrl;
      if (!url) {
        toast.error(result?.createStripeCheckoutSession?.error ?? 'Could not start checkout.');
        return;
      }
      window.location.href = url;
    } catch {
      toast.error('Could not start checkout. Please try again.');
    }
  };

  return (
    <div className="min-h-[calc(100vh-4rem)] bg-gradient-to-br from-purple-50 via-pink-50 to-blue-50 px-4 py-12">
      <Toaster position="top-center" richColors />
      <div className="mx-auto w-full max-w-2xl">
        <div className="text-center">
          <Stamp className="mx-auto h-10 w-10 text-pink-500" strokeWidth={1.5} />
          <h1 className="mt-3 text-3xl font-bold text-gray-900">Add postage</h1>
          <p className="mt-2 text-gray-600">
            Postage pays for printing and mailing physical cards. It is separate from card credits,
            and what you don&apos;t spend stays in your wallet.
          </p>
        </div>

        <div className="mt-6 flex items-center justify-center gap-2 rounded-lg border border-gray-200 bg-white px-4 py-3 text-sm">
          <Wallet className="h-4 w-4 text-gray-500" />
          <span className="text-gray-600">Current balance</span>
          <span className="font-semibold text-gray-900 tabular-nums">
            {formatCents(balanceCents)}
          </span>
        </div>

        <div className="mt-6 grid gap-3 sm:grid-cols-3">
          {TOP_UP_TIERS_CENTS.map(cents => (
            <button
              key={cents}
              type="button"
              aria-pressed={selected === cents}
              onClick={() => setSelected(cents)}
              className={cn(
                'rounded-xl border-2 bg-white px-4 py-6 text-center transition-colors',
                selected === cents
                  ? 'border-gray-900 shadow-sm'
                  : 'border-gray-200 hover:border-gray-400'
              )}
            >
              <span className="block text-2xl font-bold text-gray-900 tabular-nums">
                {formatCents(cents)}
              </span>
              <span className="mt-1 block text-xs text-gray-500">of postage</span>
            </button>
          ))}
        </div>

        <Button className="mt-6 w-full" onClick={handleCheckout} disabled={loading}>
          {loading ? 'Opening checkout…' : `Add ${formatCents(selected)} of postage`}
        </Button>

        {returnTo && (
          <p className="mt-4 text-center text-sm text-gray-500">
            <Link to={returnTo} className="underline hover:text-gray-700">
              Go back without adding postage
            </Link>
          </p>
        )}
      </div>
    </div>
  );
};

export default withAuth(BuyPostage);
