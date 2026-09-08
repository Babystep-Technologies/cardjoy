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
 * This is the minimum the send flow needs to land honestly; the full orders
 * surface and the dashboard tab are #153.
 */
import React, { useEffect } from 'react';
import { useQuery } from '@apollo/client';
import { useLocation, useNavigate, useParams } from 'react-router-dom';
import { AlertCircle, ArrowLeft, CheckCircle2, Clock, Info, Truck, XCircle } from 'lucide-react';
import withAuth from '@/lib/with-auth';
import LoadingScreen from '@/components/Loading';
import { Button } from '@/components/ui/button';
import { formatAddressSummary } from '@/lib/address';
import { formatCents, pluralize } from '@/lib/money';
import { cn } from '@/lib/utils';
import { MY_HOLIDAY_CARD_ORDERS } from './Send/queries';
import type { MailOrder } from './Send/types';

/** Statuses that are still moving. While any is on screen, keep polling. */
const OPEN_STATUSES = new Set(['pending', 'submitted', 'printing', 'processed_for_delivery']);

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

function statusStyle(status: string): { icon: React.ElementType; className: string } {
  if (status === 'completed')
    return { icon: CheckCircle2, className: 'text-green-700 bg-green-50' };
  if (status === 'failed' || status === 'cancelled') {
    return { icon: XCircle, className: 'text-red-700 bg-red-50' };
  }
  if (status === 'processed_for_delivery')
    return { icon: Truck, className: 'text-blue-700 bg-blue-50' };
  return { icon: Clock, className: 'text-gray-600 bg-gray-100' };
}

interface OrdersResponse {
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

const HolidayCardOrders: React.FC = () => {
  const { externalId = '' } = useParams<{ externalId: string }>();
  const navigate = useNavigate();
  const location = useLocation();
  const justSent = (location.state ?? null) as JustSentState | null;

  const { data, loading, error, startPolling, stopPolling } = useQuery<OrdersResponse>(
    MY_HOLIDAY_CARD_ORDERS,
    { variables: { holidayCardId: externalId }, fetchPolicy: 'cache-and-network' }
  );

  const orders = data?.myHolidayCardOrders ?? [];
  const anyOpen = orders.some(order => OPEN_STATUSES.has(order.status));

  // Polling stops the moment every piece has reached a terminal status, so a
  // finished page is not still asking the server every eight seconds.
  useEffect(() => {
    if (anyOpen) startPolling(POLL_INTERVAL_MS);
    else stopPolling();
    return stopPolling;
  }, [anyOpen, startPolling, stopPolling]);

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
          One row per card. Statuses update on their own as our print partner works through them.
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

        {error && orders.length === 0 ? (
          <div className="mt-6 flex items-start gap-2.5 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">
            <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
            <p>We could not load these orders just now. Please refresh in a moment.</p>
          </div>
        ) : orders.length === 0 ? (
          <div className="mt-6 rounded-lg border border-dashed border-gray-300 bg-white/60 p-10 text-center">
            <p className="text-gray-600">This card hasn&apos;t been mailed to anyone yet.</p>
            <Button className="mt-4" onClick={() => navigate(`/holiday-card/${externalId}/send`)}>
              Send it by post
            </Button>
          </div>
        ) : (
          <ul className="mt-6 divide-y divide-gray-100 overflow-hidden rounded-lg border border-gray-200 bg-white">
            {orders.map(order => {
              const { icon: Icon, className } = statusStyle(order.status);
              const address = formatAddressSummary({
                addressLine1: order.recipientAddress.addressLine1,
                addressLine2: order.recipientAddress.addressLine2,
                city: order.recipientAddress.city,
                region: order.recipientAddress.region,
                postalCode: order.recipientAddress.postalCode,
                countryCode: order.recipientAddress.countryCode,
              });

              return (
                <li key={order.id} className="flex flex-wrap items-start gap-3 px-4 py-3">
                  <div className="min-w-0 flex-1">
                    <p className="font-medium text-gray-900">
                      {order.recipientName ?? order.recipientAddress.name ?? 'Recipient'}
                    </p>
                    <p className="truncate text-sm text-gray-500">{address}</p>
                    {order.failureReason && (
                      <p className="mt-1 text-sm text-red-700">{order.failureReason}</p>
                    )}
                    {order.trackingNumber && (
                      <p className="mt-1 text-xs text-gray-500">Tracking {order.trackingNumber}</p>
                    )}
                  </div>
                  <div className="flex shrink-0 items-center gap-3">
                    <span
                      className={cn(
                        'inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-medium',
                        className
                      )}
                    >
                      <Icon className="h-3.5 w-3.5" />
                      {STATUS_LABELS[order.status] ?? order.status}
                    </span>
                    <span className="text-sm text-gray-900 tabular-nums">
                      {formatCents(order.chargedCents)}
                    </span>
                  </div>
                </li>
              );
            })}
          </ul>
        )}
      </div>
    </div>
  );
};

export default withAuth(HolidayCardOrders);
