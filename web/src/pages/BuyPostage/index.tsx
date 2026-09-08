/**
 * `/postage` — the postage wallet: what's in it, how to add to it, where it went.
 *
 * ## Two wallets, deliberately
 *
 * `credit_balance` is whole credits and buys digital cards. `postage_balance_cents`
 * is integer US cents and buys stamps and paper. They are not interchangeable
 * and this page never says "credits", because a user who tops up the wrong one
 * has paid for something they cannot use. The balance is named in dollars
 * throughout — it is a prepaid dollar amount, not a second currency to convert.
 *
 * ## The tiers come from the server
 *
 * `postageTopUpTiersCents` serves `PostageCredit::TOP_UP_TIERS_CENTS`, the same
 * list `createStripeCheckoutSession` validates against before charging. The
 * client no longer keeps its own copy: an amount this page can offer is, by
 * construction, an amount checkout will accept.
 */
import React, { useState } from 'react';
import { useMutation, useQuery, gql } from '@apollo/client';
import { Link } from 'react-router-dom';
import { AlertTriangle, Stamp, Wallet } from 'lucide-react';
import { Toaster, toast } from 'sonner';
import withAuth from '@/lib/with-auth';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { formatCents } from '@/lib/money';
import { cn } from '@/lib/utils';
import { describeLedgerEntry, rememberPostageCheckout } from '@/lib/postage';
import { readPostageReturnTo } from '@/pages/HolidayCard/Send/state';

const POSTAGE_WALLET = gql`
  query PostageWallet {
    viewer {
      id
      postageBalanceCents
    }
    postageTopUpTiersCents
    myPostageLedger(limit: 50) {
      id
      amountCents
      reason
      eventKind
      createdAt
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

interface LedgerEntry {
  id: string;
  amountCents: number;
  reason: string | null;
  eventKind: string | null;
  createdAt: string;
}

interface WalletResponse {
  viewer: { id: string; postageBalanceCents: number } | null;
  postageTopUpTiersCents: number[];
  myPostageLedger: LedgerEntry[];
}

interface CheckoutResponse {
  createStripeCheckoutSession: { checkoutUrl: string | null; error: string | null };
}

function formatEntryDate(iso: string): string {
  const parsed = new Date(iso);
  if (Number.isNaN(parsed.getTime())) return '';
  return parsed.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

const BuyPostage: React.FC = () => {
  const { data, loading } = useQuery<WalletResponse>(POSTAGE_WALLET, {
    fetchPolicy: 'cache-and-network',
  });
  const [createSession, { loading: startingCheckout }] =
    useMutation<CheckoutResponse>(CREATE_POSTAGE_CHECKOUT);
  const [selected, setSelected] = useState<number | null>(null);

  const balanceCents = data?.viewer?.postageBalanceCents ?? 0;
  const tiers = data?.postageTopUpTiersCents ?? [];
  const ledger = data?.myPostageLedger ?? [];
  // Mid-tier by default once the server's list arrives, so the page is never
  // waiting on a choice the user has no reason to think about.
  const activeTier = selected ?? tiers[Math.floor(tiers.length / 2)] ?? null;

  // A chargeback on a top-up already spent on mail leaves the wallet owing
  // money. Showing $0.00 there would be a lie that makes the next blocked send
  // inexplicable.
  const overdrawn = balanceCents < 0;
  // Nothing in, nothing out — distinct from "still loading", which shows bones.
  const neverUsed = !loading && ledger.length === 0;

  const returnTo = readPostageReturnTo();

  const handleCheckout = async () => {
    if (activeTier === null) return;

    // Written before we leave, because the balance is credited by a webhook
    // that lands *after* Stripe sends the user back. The success page needs the
    // number to expect a change from.
    rememberPostageCheckout({ balanceBefore: balanceCents, topUpCents: activeTier });

    try {
      const { data: result } = await createSession({ variables: { topUpCents: activeTier } });
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
          <h1 className="mt-3 text-3xl font-bold text-gray-900">Postage</h1>
          <p className="mt-2 text-gray-600">
            Postage pays for printing and mailing physical cards. It is separate from card credits,
            and what you don&apos;t spend stays here.
          </p>
        </div>

        <section
          aria-label="Postage balance"
          className={cn(
            'mt-8 rounded-2xl border bg-white p-6 text-center shadow-sm',
            overdrawn ? 'border-red-300' : 'border-gray-200'
          )}
        >
          <div className="flex items-center justify-center gap-2 text-sm text-gray-500">
            <Wallet className="h-4 w-4" />
            Balance
          </div>
          {loading && !data ? (
            <Skeleton className="mx-auto mt-2 h-10 w-36" />
          ) : (
            <p
              className={cn(
                'mt-2 text-4xl font-bold tabular-nums',
                overdrawn ? 'text-red-600' : 'text-gray-900'
              )}
            >
              {formatCents(balanceCents)}
            </p>
          )}

          {overdrawn && (
            <div className="mt-4 flex items-start gap-2 rounded-lg bg-red-50 p-3 text-left text-sm text-red-800">
              <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
              <p>
                Your wallet is overdrawn — this can happen when a payment is disputed after cards
                have already been mailed. You can&apos;t send more physical cards until the balance
                is back above {formatCents(0)}.
              </p>
            </div>
          )}
        </section>

        <section aria-label="Add postage" className="mt-8">
          <h2 className="text-lg font-semibold text-gray-900">Add postage</h2>
          <p className="mt-1 text-sm text-gray-600">
            Each card costs what it costs to print and mail — usually under a dollar, and the exact
            price depends on the card&apos;s size and where it&apos;s going. You&apos;ll see the
            total for a specific set of recipients before you send.
          </p>

          {loading && !data ? (
            <div className="mt-4 grid gap-3 sm:grid-cols-3">
              {[0, 1, 2].map(key => (
                <Skeleton key={key} className="h-[104px] rounded-xl" />
              ))}
            </div>
          ) : (
            <div className="mt-4 grid gap-3 sm:grid-cols-3">
              {tiers.map(cents => (
                <button
                  key={cents}
                  type="button"
                  aria-pressed={activeTier === cents}
                  onClick={() => setSelected(cents)}
                  className={cn(
                    'rounded-xl border-2 bg-white px-4 py-6 text-center transition-colors',
                    activeTier === cents
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
          )}

          <Button
            className="mt-4 w-full"
            onClick={handleCheckout}
            disabled={startingCheckout || activeTier === null}
          >
            {startingCheckout
              ? 'Opening checkout…'
              : activeTier === null
                ? 'Add postage'
                : `Add ${formatCents(activeTier)} of postage`}
          </Button>

          {returnTo && (
            <p className="mt-4 text-center text-sm text-gray-500">
              <Link to={returnTo} className="underline hover:text-gray-700">
                Go back without adding postage
              </Link>
            </p>
          )}
        </section>

        <section aria-label="Postage history" className="mt-10">
          <h2 className="text-lg font-semibold text-gray-900">History</h2>

          {loading && !data ? (
            <div className="mt-4 space-y-2">
              {[0, 1, 2].map(key => (
                <Skeleton key={key} className="h-14 rounded-lg" />
              ))}
            </div>
          ) : neverUsed ? (
            <p className="mt-4 rounded-xl border border-dashed border-gray-300 bg-white/60 p-6 text-center text-sm text-gray-500">
              Nothing here yet. Once you add postage or mail a card, every addition and deduction
              shows up here.
            </p>
          ) : (
            <ul className="mt-4 divide-y divide-gray-200 overflow-hidden rounded-xl border border-gray-200 bg-white">
              {ledger.map(entry => {
                const credited = entry.amountCents > 0;
                return (
                  <li key={entry.id} className="flex items-center justify-between gap-4 px-4 py-3">
                    <div className="min-w-0">
                      <p className="truncate text-sm font-medium text-gray-900">
                        {describeLedgerEntry(entry.eventKind, entry.reason)}
                      </p>
                      <p className="text-xs text-gray-500">{formatEntryDate(entry.createdAt)}</p>
                    </div>
                    {/* The sign is carried by an explicit +/- as well as colour,
                        so the direction survives for anyone who can't tell green
                        from red. */}
                    <span
                      className={cn(
                        'shrink-0 text-sm font-semibold tabular-nums',
                        credited ? 'text-green-700' : 'text-gray-900'
                      )}
                    >
                      {credited ? '+' : '−'}
                      {formatCents(Math.abs(entry.amountCents))}
                    </span>
                  </li>
                );
              })}
            </ul>
          )}
        </section>
      </div>
    </div>
  );
};

export default withAuth(BuyPostage);
