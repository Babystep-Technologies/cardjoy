/**
 * `/buy_postage/success` — back from Stripe, and back to whatever you were doing.
 *
 * The path is Stripe's, fixed on the server; the wallet itself lives at
 * `/postage`.
 *
 * ## The balance is credited by a webhook, not by this redirect
 *
 * Stripe returns the user the instant they pay. `checkout.session.completed`
 * arrives separately, usually a second or two later. So there is a window where
 * the money is real and the balance still reads the old number — and a page
 * that shows that number tells the user, confidently and wrongly, that their
 * payment did nothing.
 *
 * The fix is knowing what to expect. `/postage` writes down the balance *before*
 * the redirect, so this page can tell "the webhook hasn't landed yet" apart from
 * "this is the new balance" instead of guessing from a bare number. Until the
 * balance actually moves, it says so.
 *
 * If the note is missing — private browsing, a shared link, a new tab — the
 * page degrades to reporting whatever the server says, without claiming the
 * top-up has landed.
 *
 * Nothing here blocks: the send flow re-prices and re-reads the balance when the
 * user gets back to it, so a slow webhook costs a moment of copy, not a send.
 */
import React, { useEffect, useRef, useState } from 'react';
import { gql, useQuery } from '@apollo/client';
import { Link, useNavigate } from 'react-router-dom';
import { CheckCircle, Loader2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { formatCents } from '@/lib/money';
import { clearPostageCheckout, readPostageCheckout } from '@/lib/postage';
import { clearPostageReturnTo, readPostageReturnTo } from '@/pages/HolidayCard/Send/state';

const POSTAGE_BALANCE = gql`
  query PostageBalanceAfterTopUp {
    viewer {
      id
      postageBalanceCents
    }
  }
`;

/** Long enough to cover a normal webhook, short enough not to feel stuck. */
const POLL_INTERVAL_MS = 2000;
const POLL_CEILING_MS = 20000;

interface BalanceResponse {
  viewer: { id: string; postageBalanceCents: number } | null;
}

const BuyPostageSuccess: React.FC = () => {
  const navigate = useNavigate();
  // Read once, on mount: both notes are cleared as soon as they have been used,
  // and re-reading after that would lose them mid-render.
  const [returnTo] = useState(() => readPostageReturnTo());
  const [checkout] = useState(() => readPostageCheckout());
  const [gaveUpWaiting, setGaveUpWaiting] = useState(false);

  const { data, startPolling, stopPolling } = useQuery<BalanceResponse>(POSTAGE_BALANCE, {
    fetchPolicy: 'network-only',
  });

  const balanceCents = data?.viewer?.postageBalanceCents;
  // The webhook has landed once the balance differs from what we wrote down.
  // Compared for *change*, not for the exact expected total: a piece of mail or
  // a refund can settle in the same window, and demanding an exact number would
  // leave the page spinning through a balance that is already correct.
  const landed =
    checkout != null && balanceCents !== undefined && balanceCents !== checkout.balanceBefore;
  const waiting = !landed && !gaveUpWaiting;

  // Only meaningful while we are still waiting on a note we can act on.
  const shouldPoll = checkout != null && waiting;

  // The note has done its job the moment we can see the money; leaving it would
  // make a later, unrelated visit compare against a stale balance.
  useEffect(() => {
    if (landed) clearPostageCheckout();
  }, [landed]);

  const stopPollingRef = useRef(stopPolling);
  stopPollingRef.current = stopPolling;

  useEffect(() => {
    if (!shouldPoll) {
      stopPollingRef.current();
      return;
    }

    startPolling(POLL_INTERVAL_MS);
    // A webhook that never arrives must not spin forever: past the ceiling the
    // page stops claiming to be mid-flight and shows what it actually knows.
    const timer = window.setTimeout(() => {
      stopPollingRef.current();
      setGaveUpWaiting(true);
    }, POLL_CEILING_MS);

    return () => {
      window.clearTimeout(timer);
      stopPollingRef.current();
    };
  }, [shouldPoll, startPolling]);

  const handleContinue = () => {
    clearPostageCheckout();
    clearPostageReturnTo();
    navigate(returnTo ?? '/postage');
  };

  return (
    <div className="flex min-h-[calc(100vh-4rem)] items-center justify-center px-4 py-20">
      <div className="w-full max-w-xl space-y-6 text-center">
        <CheckCircle className="mx-auto h-16 w-16 text-green-500" strokeWidth={1.5} />
        <h1 className="text-3xl font-bold text-gray-900">
          {checkout && waiting ? 'Payment received' : 'Postage added'}
        </h1>

        <div className="text-gray-600">
          {checkout && waiting ? (
            <p className="inline-flex items-center gap-2">
              <Loader2 className="h-4 w-4 animate-spin" />
              Adding {formatCents(checkout.topUpCents)} to your postage balance…
            </p>
          ) : balanceCents === undefined ? (
            <p className="inline-flex items-center gap-2">
              <Loader2 className="h-4 w-4 animate-spin" />
              Checking your wallet…
            </p>
          ) : (
            <p>
              Your postage balance is{' '}
              <span className="font-semibold text-gray-900 tabular-nums">
                {formatCents(balanceCents)}
              </span>
              .
            </p>
          )}

          {/* Said only when we have actually been waiting a while — reassurance
              offered up front reads as an excuse for a problem the user does
              not yet have. */}
          {gaveUpWaiting && !landed && (
            <p className="mt-2 text-sm text-gray-500">
              Your payment went through. It&apos;s taking a moment to appear — refresh in a few
              seconds, and contact us if it hasn&apos;t landed.
            </p>
          )}
        </div>

        {returnTo ? (
          <>
            <Button onClick={handleContinue}>Back to your card</Button>
            <p className="text-sm text-gray-500">
              Your recipients are still selected, exactly as you left them.
            </p>
          </>
        ) : (
          <Link
            to="/postage"
            className="inline-block rounded-xl bg-black px-6 py-3 font-semibold text-white transition-colors hover:bg-gray-800"
            onClick={clearPostageCheckout}
          >
            View your postage
          </Link>
        )}
      </div>
    </div>
  );
};

export default BuyPostageSuccess;
