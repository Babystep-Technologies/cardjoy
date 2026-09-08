/**
 * `/buy_postage/success` — back from Stripe, and back to whatever you were doing.
 *
 * Stripe's return URL is fixed on the server and carries only a session id, so
 * nothing in the round trip says the user was half-way through mailing forty
 * cards. The note the send flow left in `sessionStorage` is what does, and
 * following it is the whole point of this page: their recipient selection is
 * still in storage, waiting.
 *
 * **The balance is credited by a webhook, not by this redirect.** Stripe sends
 * the user back the moment they pay; `checkout.session.completed` arrives
 * separately, usually a second or two later. So the page polls briefly rather
 * than asserting a number it has not seen yet — and never blocks on it, because
 * the send flow re-prices and re-reads the balance on its own when the user
 * gets back there.
 */
import React, { useEffect } from 'react';
import { gql, useQuery } from '@apollo/client';
import { Link, useNavigate } from 'react-router-dom';
import { CheckCircle, Loader2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { formatCents } from '@/lib/money';
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
  // Read once, on mount: the note is cleared as soon as it has been used, and
  // re-reading it after that would lose the destination mid-render.
  const [returnTo] = React.useState(() => readPostageReturnTo());

  const { data, startPolling, stopPolling } = useQuery<BalanceResponse>(POSTAGE_BALANCE, {
    fetchPolicy: 'network-only',
    pollInterval: POLL_INTERVAL_MS,
  });

  useEffect(() => {
    startPolling(POLL_INTERVAL_MS);
    const timer = window.setTimeout(stopPolling, POLL_CEILING_MS);
    return () => {
      window.clearTimeout(timer);
      stopPolling();
    };
  }, [startPolling, stopPolling]);

  const balanceCents = data?.viewer?.postageBalanceCents;

  const handleContinue = () => {
    clearPostageReturnTo();
    navigate(returnTo ?? '/dashboard');
  };

  return (
    <div className="flex min-h-[calc(100vh-4rem)] items-center justify-center px-4 py-20">
      <div className="w-full max-w-xl space-y-6 text-center">
        <CheckCircle className="mx-auto h-16 w-16 text-green-500" strokeWidth={1.5} />
        <h1 className="text-3xl font-bold text-gray-900">Postage added</h1>

        <p className="text-gray-600">
          {balanceCents === undefined ? (
            <span className="inline-flex items-center gap-2">
              <Loader2 className="h-4 w-4 animate-spin" />
              Checking your wallet…
            </span>
          ) : (
            <>
              Your postage wallet balance is{' '}
              <span className="font-semibold text-gray-900 tabular-nums">
                {formatCents(balanceCents)}
              </span>
              . It can take a moment to land — if it looks low, give it a few seconds.
            </>
          )}
        </p>

        {returnTo ? (
          <>
            <Button onClick={handleContinue}>Back to your card</Button>
            <p className="text-sm text-gray-500">
              Your recipients are still selected, exactly as you left them.
            </p>
          </>
        ) : (
          <Link
            to="/dashboard"
            className="inline-block rounded-xl bg-black px-6 py-3 font-semibold text-white transition-colors hover:bg-gray-800"
          >
            Back to dashboard
          </Link>
        )}
      </div>
    </div>
  );
};

export default BuyPostageSuccess;
