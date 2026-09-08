/**
 * `/holiday-card/:externalId/orders` — where the cards went, and how far.
 *
 * The send flow lands here rather than on a confirmation screen, because
 * `sendHolidayCard` returns with every order `pending`: nothing has been
 * submitted to the print partner yet, and the outcome is per-piece. A dead-end
 * "sent!" page would be the one screen that cannot tell the user what actually
 * happened. This one updates.
 *
 * **Partial failure is the normal case.** Thirty-eight pieces can go out while
 * two are rejected and refund themselves, so this is one row per piece with its
 * own status and its own refund, not a batch with a single verdict.
 *
 * ## Why failures sort to the top
 *
 * A refunded piece is the only row on this page that asks something of the
 * reader: someone did not get a card, and there is money back in the wallet to
 * spend on trying again. In a list of forty successes it is two rows of
 * scrolling away, and physical mail is slow enough that nobody comes back to
 * check. So `ORDER_OF_CONCERN` sorts by how much a row needs attention before
 * it sorts by time, and a banner counts the failures above the list regardless
 * of which filter is showing.
 */
import React, { useEffect, useMemo, useState } from 'react';
import { useQuery } from '@apollo/client';
import { Link, useLocation, useNavigate, useParams } from 'react-router-dom';
import {
  AlertCircle,
  AlertTriangle,
  ArrowLeft,
  CheckCircle2,
  Clock,
  ExternalLink,
  Info,
  Truck,
  XCircle,
} from 'lucide-react';
import { format, parseISO } from 'date-fns';
import withAuth from '@/lib/with-auth';
import LoadingScreen from '@/components/Loading';
import { Button } from '@/components/ui/button';
import { formatAddressSummary } from '@/lib/address';
import { formatCents, pluralize } from '@/lib/money';
import { cn } from '@/lib/utils';
import { GET_ORDERS } from './queries';
import type { MailOrder } from './Send/types';

/** Statuses that are still moving. While any is on screen, keep polling. */
const OPEN_STATUSES = new Set(['pending', 'submitted', 'printing', 'processed_for_delivery']);

/** Terminal and refunded. Both mean: it will not arrive, and the money came back. */
const REFUNDED_STATUSES = new Set(['failed', 'cancelled']);

const POLL_INTERVAL_MS = 8000;

const STATUS_LABELS: Record<string, string> = {
  pending: 'Queued',
  submitted: 'With the printer',
  printing: 'Printing',
  processed_for_delivery: 'In the post',
  completed: 'Delivered',
  failed: 'Failed — refunded',
  cancelled: 'Cancelled — refunded',
};

/**
 * How loudly a row asks to be read. Refunded first, then everything still in
 * motion, then the ones that are simply done — see the header comment.
 */
const ORDER_OF_CONCERN = (status: string): number => {
  if (REFUNDED_STATUSES.has(status)) return 0;
  if (OPEN_STATUSES.has(status)) return 1;
  return 2;
};

function statusStyle(status: string): { icon: React.ElementType; className: string } {
  if (status === 'completed')
    return { icon: CheckCircle2, className: 'text-green-700 bg-green-50' };
  if (REFUNDED_STATUSES.has(status)) {
    return { icon: XCircle, className: 'text-red-700 bg-red-50' };
  }
  if (status === 'processed_for_delivery')
    return { icon: Truck, className: 'text-blue-700 bg-blue-50' };
  return { icon: Clock, className: 'text-gray-600 bg-gray-100' };
}

/**
 * USPS tracking, which is who carries these: PostGrid mails domestic pieces as
 * USPS First Class or Standard, so a tracking number on one of our orders is a
 * USPS label. `tLabels` accepts the bare number.
 */
const uspsTrackingUrl = (trackingNumber: string): string =>
  `https://tools.usps.com/go/TrackConfirmAction?tLabels=${encodeURIComponent(trackingNumber)}`;

type FilterKey = 'all' | 'attention' | 'open' | 'delivered';

const FILTERS: { key: FilterKey; label: string; matches: (status: string) => boolean }[] = [
  { key: 'all', label: 'All', matches: () => true },
  { key: 'attention', label: 'Needs attention', matches: status => REFUNDED_STATUSES.has(status) },
  { key: 'open', label: 'On its way', matches: status => OPEN_STATUSES.has(status) },
  { key: 'delivered', label: 'Delivered', matches: status => status === 'completed' },
];

interface OrdersResponse {
  holidayCard: { externalId: string; title: string | null } | null;
  myHolidayCardOrders: MailOrder[];
}

/**
 * What the send flow hands over on arrival: how many went out, and — because a
 * price is only ever advisory until the server charges it — what was actually
 * debited versus what the user was shown.
 */
interface JustSentState {
  justSent?: number;
  chargedCents?: number;
  expectedCents?: number;
}

/** "Sent 3 Dec", or nothing at all rather than a crash on an unparseable date. */
function formatDay(iso: string | null): string | null {
  if (!iso) return null;
  try {
    return format(parseISO(iso), 'd MMM');
  } catch {
    return null;
  }
}

const HolidayCardOrders: React.FC = () => {
  const { externalId = '' } = useParams<{ externalId: string }>();
  const navigate = useNavigate();
  const location = useLocation();
  const justSent = (location.state ?? null) as JustSentState | null;

  const [filter, setFilter] = useState<FilterKey>('all');

  const { data, loading, error, startPolling, stopPolling } = useQuery<OrdersResponse>(GET_ORDERS, {
    // `externalId` reads the card, `holidayCardId` scopes the orders. The API
    // takes the same public id under both names.
    variables: { externalId, holidayCardId: externalId },
    fetchPolicy: 'cache-and-network',
  });

  const orders = useMemo(() => data?.myHolidayCardOrders ?? [], [data]);
  const card = data?.holidayCard ?? null;
  const anyOpen = orders.some(order => OPEN_STATUSES.has(order.status));

  // Polling stops the moment every piece has reached a terminal status, so a
  // finished page is not still asking the server every eight seconds.
  useEffect(() => {
    if (anyOpen) startPolling(POLL_INTERVAL_MS);
    else stopPolling();
    return stopPolling;
  }, [anyOpen, startPolling, stopPolling]);

  const counts = useMemo(() => {
    const tally = { all: orders.length, attention: 0, open: 0, delivered: 0 };
    orders.forEach(order => {
      if (REFUNDED_STATUSES.has(order.status)) tally.attention += 1;
      else if (OPEN_STATUSES.has(order.status)) tally.open += 1;
      else if (order.status === 'completed') tally.delivered += 1;
    });
    return tally;
  }, [orders]);

  const refundedCents = useMemo(
    () =>
      orders
        .filter(order => REFUNDED_STATUSES.has(order.status))
        .reduce((total, order) => total + order.chargedCents, 0),
    [orders]
  );

  // Sorted before filtering, so every filter shows the same ordering rather
  // than one that depends on which chip is active.
  const visible = useMemo(() => {
    const matches = FILTERS.find(entry => entry.key === filter)?.matches ?? (() => true);
    return orders
      .filter(order => matches(order.status))
      .sort((a, b) => {
        const concern = ORDER_OF_CONCERN(a.status) - ORDER_OF_CONCERN(b.status);
        if (concern !== 0) return concern;
        return b.createdAt.localeCompare(a.createdAt);
      });
  }, [orders, filter]);

  if (loading && orders.length === 0) return <LoadingScreen />;

  // A charge that did not match what was displayed. The server re-prices inside
  // the debit transaction and never asks the client for a number, so this can
  // legitimately happen — and the user is told rather than left to find it in
  // their wallet later.
  const chargeDiffers =
    justSent?.chargedCents !== undefined &&
    justSent?.expectedCents !== undefined &&
    justSent.chargedCents !== justSent.expectedCents;

  return (
    <div className="min-h-[calc(100vh-4rem)] bg-gradient-to-br from-purple-50 via-pink-50 to-blue-50 px-4 py-8">
      <div className="mx-auto w-full max-w-3xl">
        <Button
          variant="ghost"
          size="sm"
          className="-ml-2 gap-1.5"
          onClick={() => navigate('/dashboard')}
        >
          <ArrowLeft className="h-4 w-4" />
          Dashboard
        </Button>
        <h1 className="mt-1 text-3xl font-bold text-gray-900">Mailed cards</h1>
        <p className="mt-1 text-gray-600">
          {card?.title ? `“${card.title}” — one row per card. ` : 'One row per card. '}
          Statuses update on their own as our print partner works through them.
        </p>

        {justSent?.justSent ? (
          <div className="mt-6 flex items-start gap-2.5 rounded-lg border border-green-200 bg-green-50 px-4 py-3 text-sm text-green-900">
            <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0" />
            <div>
              <p>
                <span className="font-semibold">
                  {pluralize(justSent.justSent, 'card')} queued for printing.
                </span>{' '}
                They&apos;ll move through the statuses below over the next few days.
              </p>
              {justSent.chargedCents !== undefined && (
                <p className="mt-1">
                  {formatCents(justSent.chargedCents)} was taken from your postage wallet.
                </p>
              )}
            </div>
          </div>
        ) : null}

        {chargeDiffers && (
          <div className="mt-3 flex items-start gap-2.5 rounded-lg border border-amber-300 bg-amber-50 px-4 py-3 text-sm text-amber-900">
            <Info className="mt-0.5 h-4 w-4 shrink-0" />
            <p>
              The final price came out at{' '}
              <span className="font-medium tabular-nums">
                {formatCents(justSent!.chargedCents!)}
              </span>{' '}
              rather than the{' '}
              <span className="font-medium tabular-nums">
                {formatCents(justSent!.expectedCents!)}
              </span>{' '}
              we showed you. Prices are re-checked against each address at the moment of sending,
              and this is what you were charged.
            </p>
          </div>
        )}

        {/* Above the filters on purpose: a filtered-down list must not be able
            to hide the fact that something failed. */}
        {counts.attention > 0 && (
          <div className="mt-3 flex items-start gap-2.5 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-900">
            <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
            <div>
              <p className="font-semibold">
                {counts.attention === 1
                  ? "1 card couldn't be sent."
                  : `${counts.attention} cards couldn't be sent.`}
              </p>
              <p className="mt-1">
                {formatCents(refundedCents)} went back to your postage balance — nothing was kept
                for a card that was never mailed. Fix the address and send again when you&apos;re
                ready.
              </p>
              <div className="mt-2 flex flex-wrap gap-3">
                {filter !== 'attention' && (
                  <button
                    type="button"
                    onClick={() => setFilter('attention')}
                    className="font-medium underline underline-offset-2"
                  >
                    Show just these
                  </button>
                )}
                <Link to="/postage" className="font-medium underline underline-offset-2">
                  View postage balance
                </Link>
              </div>
            </div>
          </div>
        )}

        {error && orders.length === 0 ? (
          <div className="mt-6 flex items-start gap-2.5 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">
            <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
            <p>We could not load these orders just now. Please refresh in a moment.</p>
          </div>
        ) : orders.length === 0 ? (
          <div className="mt-6 rounded-lg border border-dashed border-gray-300 bg-white/60 p-10 text-center">
            <p className="text-gray-600">This card hasn&apos;t been mailed to anyone yet.</p>
            <p className="mt-1 text-sm text-gray-500">
              Once you send it, every recipient gets a row here that you can follow to the doormat.
            </p>
            <Button className="mt-4" onClick={() => navigate(`/holiday-card/${externalId}/send`)}>
              Send it by post
            </Button>
          </div>
        ) : (
          <>
            <div className="mt-6 flex flex-wrap gap-2">
              {FILTERS.map(entry => (
                <button
                  key={entry.key}
                  type="button"
                  onClick={() => setFilter(entry.key)}
                  aria-pressed={filter === entry.key}
                  className={cn(
                    'rounded-full border px-3 py-1 text-xs font-medium transition-colors',
                    filter === entry.key
                      ? 'border-gray-900 bg-gray-900 text-white'
                      : 'border-gray-200 bg-white text-gray-600 hover:border-gray-300'
                  )}
                >
                  {entry.label} ({counts[entry.key]})
                </button>
              ))}
            </div>

            {visible.length === 0 ? (
              <div className="mt-4 rounded-lg border border-dashed border-gray-300 bg-white/60 p-8 text-center text-sm text-gray-600">
                Nothing in this group right now.
              </div>
            ) : (
              <ul className="mt-4 divide-y divide-gray-100 overflow-hidden rounded-lg border border-gray-200 bg-white">
                {visible.map(order => {
                  const { icon: Icon, className } = statusStyle(order.status);
                  const refunded = REFUNDED_STATUSES.has(order.status);
                  const address = formatAddressSummary({
                    addressLine1: order.recipientAddress.addressLine1,
                    addressLine2: order.recipientAddress.addressLine2,
                    city: order.recipientAddress.city,
                    region: order.recipientAddress.region,
                    postalCode: order.recipientAddress.postalCode,
                    countryCode: order.recipientAddress.countryCode,
                  });
                  const sentOn = formatDay(order.mailedAt ?? order.submittedAt ?? order.createdAt);

                  return (
                    <li
                      key={order.id}
                      className={cn(
                        'flex flex-wrap items-start gap-3 px-4 py-3',
                        refunded && 'bg-red-50/40'
                      )}
                    >
                      <div className="min-w-0 flex-1">
                        <p className="font-medium text-gray-900">
                          {order.recipientName ?? order.recipientAddress.name ?? 'Recipient'}
                        </p>
                        {/* The snapshot, deliberately: this is where the card
                            went, not where the contact lives today. */}
                        <p className="truncate text-sm text-gray-500">{address}</p>

                        {refunded && (
                          <div className="mt-1.5 rounded-md bg-red-100/70 px-2.5 py-1.5 text-sm text-red-800">
                            <p>
                              {order.failureReason ??
                                'This card was cancelled before it went into the post.'}
                            </p>
                            <p className="mt-0.5 font-medium">
                              {formatCents(order.chargedCents)} was refunded to your postage
                              balance.
                            </p>
                          </div>
                        )}

                        {order.trackingNumber && (
                          <a
                            href={uspsTrackingUrl(order.trackingNumber)}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="mt-1 inline-flex items-center gap-1 text-xs font-medium text-blue-700 hover:underline"
                          >
                            Track {order.trackingNumber}
                            <ExternalLink className="h-3 w-3" />
                          </a>
                        )}
                      </div>
                      <div className="flex shrink-0 flex-col items-end gap-1">
                        <span
                          className={cn(
                            'inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-medium',
                            className
                          )}
                        >
                          <Icon className="h-3.5 w-3.5" />
                          {STATUS_LABELS[order.status] ?? order.status}
                        </span>
                        {/* Struck through when refunded, so the amount never
                            reads as money the user is still out. */}
                        <span
                          className={cn(
                            'text-sm tabular-nums',
                            refunded ? 'text-gray-400 line-through' : 'text-gray-900'
                          )}
                        >
                          {formatCents(order.chargedCents)}
                        </span>
                        {sentOn && <span className="text-xs text-gray-400">{sentOn}</span>}
                      </div>
                    </li>
                  );
                })}
              </ul>
            )}
          </>
        )}
      </div>
    </div>
  );
};

export default withAuth(HolidayCardOrders);
