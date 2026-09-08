/**
 * Stage 3 — what it costs, what you have, and the last word before it prints (#151).
 *
 * ## Prices are advisory, and this screen behaves like it
 *
 * `quoteHolidayCardMailing` is an estimate. The server re-prices inside the
 * transaction that debits the wallet, because an address — and therefore a
 * zone, and therefore a price — can be edited between looking and sending, and
 * **no mutation argument anywhere accepts a price from a client**. So this
 * screen never treats its total as a promise:
 *
 * - Pressing the confirm button re-quotes first. If the number moved, the send
 *   stops and shows the difference. The user confirms the new total or walks
 *   away; nothing is charged on a price they were not shown.
 * - After the send, `totalChargedCents` is compared against what was displayed
 *   one more time, and any difference is carried to the order list rather than
 *   swallowed. Two checks, because the first closes a window and the second
 *   closes the race inside it.
 *
 * ## Money
 *
 * Every amount here is an integer number of cents from the API, summed as
 * integers and formatted once by `formatCents`. Nothing in this file divides by
 * 100.
 */
import React, { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { AlertCircle, AlertTriangle, Loader2, MapPinPlus, Printer, Wallet } from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { formatAddressSummary } from '@/lib/address';
import { formatCents, pluralize } from '@/lib/money';
import { cn } from '@/lib/utils';
import MailableCount from './MailableCount';
import AddressDialog from './AddressDialog';
import type { SendFailure } from './sendErrors';
import type { MailingQuote, SendContact } from './types';

type ReviewStageProps = {
  quote: MailingQuote | null;
  quoteLoading: boolean;
  quoteError: string | null;
  /** How many recipients the user picked, mailable or not — the count sentence. */
  selectedCount: number;
  cardTitle: string | null;
  sending: boolean;
  failures: SendFailure[];
  /** Re-runs the quote against the server. Resolves to the fresh quote, or null. */
  onRequote: () => Promise<MailingQuote | null>;
  /** Contact ids only. There is no price argument, by design. */
  onSend: (contactIds: string[], expectedTotalCents: number) => void;
  onRefetch: () => Promise<unknown> | void;
  onBack: () => void;
  /** Where the postage top-up should return to, with this selection intact. */
  topUpPath: string;
};

export const ReviewStage: React.FC<ReviewStageProps> = ({
  quote,
  quoteLoading,
  quoteError,
  selectedCount,
  cardTitle,
  sending,
  failures,
  onRequote,
  onSend,
  onRefetch,
  onBack,
  topUpPath,
}) => {
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [checking, setChecking] = useState(false);
  const [addressFor, setAddressFor] = useState<SendContact | null>(null);
  /**
   * Set when a re-quote disagreed with what was on screen. It holds the *old*
   * number, because the new one is already in `quote` — what the dialog has to
   * show is the change, not just the result.
   */
  const [priceMoved, setPriceMoved] = useState<{ from: number; to: number } | null>(null);

  /**
   * A rejected send closes the dialog.
   *
   * The failure notice renders on the page, and the confirm dialog covers it —
   * so leaving the dialog up shows the user an unchanged "Yes, mail 2 cards"
   * button and hides the sentence explaining why the last press did nothing.
   * Every one of these failures needs an action taken *behind* the dialog: top
   * up, regenerate the proof, fix an address.
   */
  useEffect(() => {
    if (failures.length > 0) setConfirmOpen(false);
  }, [failures]);

  const priced = useMemo(
    () => (quote?.entries ?? []).filter(entry => entry.totalCents !== null),
    [quote]
  );
  const blocked = useMemo(
    () => (quote?.entries ?? []).filter(entry => entry.totalCents === null),
    [quote]
  );

  const totalCents = quote?.totalCents ?? 0;
  const balanceCents = quote?.postageBalanceCents ?? 0;
  // Integer cents throughout — a shortfall is a subtraction, never a comparison
  // of two rounded dollar strings.
  const shortfallCents = Math.max(0, totalCents - balanceCents);
  const shortOfPostage = shortfallCents > 0;

  const handleConfirmClick = async () => {
    if (priced.length === 0) return;

    setChecking(true);
    setPriceMoved(null);
    try {
      // The quote on screen may be minutes old. Ask again before opening a
      // dialog whose button spends money.
      const fresh = await onRequote();
      const freshTotal = fresh?.totalCents ?? totalCents;
      const freshPriced = (fresh?.entries ?? []).filter(entry => entry.totalCents !== null);

      // The re-quote can price this send above the wallet. Opening a confirm
      // dialog on a total the user cannot afford would put them one button away
      // from a rejection the page already knows is coming — the shortfall panel
      // is on screen by now, and it is the honest thing to leave them looking at.
      if (fresh && freshTotal > (fresh.postageBalanceCents ?? 0)) return;

      if (fresh && (freshTotal !== totalCents || freshPriced.length !== priced.length)) {
        setPriceMoved({ from: totalCents, to: freshTotal });
      }
      setConfirmOpen(true);
    } finally {
      setChecking(false);
    }
  };

  const handleSend = () => {
    if (priced.length === 0) return;
    onSend(
      priced.map(entry => entry.contact.id),
      totalCents
    );
  };

  const addressDialogContact = addressFor
    ? ((quote?.entries ?? []).find(entry => entry.contact.id === addressFor.id)?.contact ??
      addressFor)
    : null;

  if (quoteLoading && !quote) {
    return (
      <div className="flex items-center justify-center gap-2 py-20 text-gray-500">
        <Loader2 className="h-4 w-4 animate-spin" />
        Pricing your recipients…
      </div>
    );
  }

  if (quoteError && !quote) {
    return (
      <div className="space-y-4">
        <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">
          {quoteError}
        </div>
        <Button variant="outline" onClick={onBack}>
          Back to the proof
        </Button>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <MailableCount selected={selectedCount} mailable={priced.length} />

      {failures.length > 0 && (
        <div className="space-y-2">
          {failures.map(failure => (
            <SendFailureNotice key={failure.message} failure={failure} topUpPath={topUpPath} />
          ))}
        </div>
      )}

      {blocked.length > 0 && (
        <section className="rounded-lg border border-amber-300 bg-amber-50 p-4">
          <h2 className="flex items-center gap-2 text-sm font-semibold text-amber-900">
            <AlertTriangle className="h-4 w-4" />
            {pluralize(blocked.length, 'recipient')} won&apos;t get a card
          </h2>
          <ul className="mt-3 space-y-2">
            {blocked.map(entry => (
              <li
                key={entry.contact.id}
                className="flex flex-wrap items-center justify-between gap-2 text-sm"
              >
                <span className="text-amber-900">
                  <span className="font-medium">{entry.contact.name}</span>
                  <span className="ml-2 text-amber-700">
                    {entry.reason ?? 'No deliverable address'}
                  </span>
                </span>
                <Button
                  variant="outline"
                  size="sm"
                  className="bg-white"
                  onClick={() => setAddressFor(entry.contact)}
                >
                  <MapPinPlus className="mr-1.5 h-3.5 w-3.5" />
                  {entry.contact.mailable ? 'Fix address' : 'Add address'}
                </Button>
              </li>
            ))}
          </ul>
          <p className="mt-3 text-xs text-amber-800">
            They are not included in the total below and you will not be charged for them.
          </p>
        </section>
      )}

      <section className="overflow-hidden rounded-lg border border-gray-200 bg-white">
        <h2 className="border-b bg-gray-50 px-4 py-2.5 text-sm font-semibold text-gray-800">
          {pluralize(priced.length, 'card')} to mail
        </h2>
        {priced.length === 0 ? (
          <p className="px-4 py-8 text-center text-sm text-gray-600">
            None of your selected recipients can be mailed yet. Add an address above, or go back and
            pick someone else.
          </p>
        ) : (
          <ul className="divide-y divide-gray-100">
            {priced.map(entry => (
              <li key={entry.contact.id} className="flex items-start gap-4 px-4 py-3">
                <div className="min-w-0 flex-1">
                  <p className="font-medium text-gray-900">{entry.contact.name}</p>
                  <p className="truncate text-sm text-gray-500">
                    {formatAddressSummary(entry.contact)}
                  </p>
                </div>
                <p className="shrink-0 text-sm font-medium text-gray-900 tabular-nums">
                  {formatCents(entry.totalCents ?? 0)}
                </p>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section className="rounded-lg border border-gray-200 bg-white p-4">
        <dl className="space-y-2 text-sm">
          <div className="flex items-center justify-between">
            <dt className="text-gray-600">Total for this send</dt>
            <dd className="text-lg font-semibold text-gray-900 tabular-nums">
              {formatCents(totalCents)}
            </dd>
          </div>
          <div className="flex items-center justify-between">
            <dt className="flex items-center gap-1.5 text-gray-600">
              <Wallet className="h-3.5 w-3.5" />
              Postage wallet balance
            </dt>
            <dd className="tabular-nums text-gray-900">{formatCents(balanceCents)}</dd>
          </div>
          {shortOfPostage && (
            <div className="flex items-center justify-between border-t pt-2">
              <dt className="font-medium text-red-700">You&apos;re short</dt>
              <dd className="font-semibold text-red-700 tabular-nums">
                {formatCents(shortfallCents)}
              </dd>
            </div>
          )}
        </dl>

        <p className="mt-3 text-xs text-gray-500">
          Prices are checked again the moment we send, so this total is an estimate until then.
        </p>

        {shortOfPostage && (
          <div className="mt-4 rounded-md border border-red-200 bg-red-50 p-3">
            <p className="text-sm text-red-800">
              Add at least <strong>{formatCents(shortfallCents)}</strong> of postage to send these{' '}
              {pluralize(priced.length, 'card')}.
            </p>
            <Link
              to={topUpPath}
              className="mt-3 inline-flex items-center rounded-md bg-gray-900 px-3.5 py-2 text-sm font-medium text-white hover:bg-gray-800"
            >
              Add postage
            </Link>
            <p className="mt-2 text-xs text-red-700">
              We&apos;ll bring you straight back here, with these recipients still selected.
            </p>
          </div>
        )}
      </section>

      <div className="flex flex-wrap items-center justify-between gap-3 border-t pt-4">
        <Button variant="outline" onClick={onBack} disabled={sending}>
          Back to the proof
        </Button>
        <Button
          onClick={handleConfirmClick}
          disabled={priced.length === 0 || shortOfPostage || sending || checking}
        >
          <Printer className="mr-2 h-4 w-4" />
          {checking ? 'Checking prices…' : `Send ${pluralize(priced.length, 'card')}`}
        </Button>
      </div>

      <ConfirmDialog
        open={confirmOpen}
        onOpenChange={open => !sending && setConfirmOpen(open)}
        count={priced.length}
        totalCents={totalCents}
        cardTitle={cardTitle}
        priceMoved={priceMoved}
        sending={sending}
        onConfirm={handleSend}
      />

      <AddressDialog
        contact={addressDialogContact}
        onClose={() => setAddressFor(null)}
        onSaved={onRefetch}
      />
    </div>
  );
};

/**
 * The last screen before printing starts.
 *
 * It says what happens in words rather than only in a total, because "Send 38
 * cards — $95.00" describes a transaction and this is a physical, irreversible
 * act: paper, a printer, and a postal service that will not give any of it back.
 *
 * When a re-quote moved the price it says so here and re-states the new total,
 * so the button the user presses is always attached to the number they just
 * read.
 */
const ConfirmDialog: React.FC<{
  open: boolean;
  onOpenChange: (open: boolean) => void;
  count: number;
  totalCents: number;
  cardTitle: string | null;
  priceMoved: { from: number; to: number } | null;
  sending: boolean;
  onConfirm: () => void;
}> = ({ open, onOpenChange, count, totalCents, cardTitle, priceMoved, sending, onConfirm }) => (
  <Dialog open={open} onOpenChange={onOpenChange}>
    <DialogContent>
      <DialogHeader>
        <DialogTitle>Mail {pluralize(count, 'printed card')}?</DialogTitle>
        <DialogDescription>
          {cardTitle ? `“${cardTitle}”` : 'This card'} will be printed on paper and handed to the
          postal service.
        </DialogDescription>
      </DialogHeader>

      {priceMoved && (
        <div className="flex items-start gap-2.5 rounded-md border border-amber-300 bg-amber-50 p-3 text-sm text-amber-900">
          <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
          <p>
            The price changed while you were reviewing — it was{' '}
            <span className="font-medium tabular-nums">{formatCents(priceMoved.from)}</span> and is
            now <span className="font-medium tabular-nums">{formatCents(priceMoved.to)}</span>.
            Nothing has been charged. Confirm below only if the new total is right.
          </p>
        </div>
      )}

      <div className="space-y-3 text-sm text-gray-700">
        <p className="rounded-md border border-gray-200 bg-gray-50 p-3">
          <strong className="font-semibold">This cannot be undone once printing starts.</strong> We
          can&apos;t recall a card, change what it says, or change where it&apos;s going. If a
          particular card is rejected before it&apos;s printed, that card&apos;s postage is refunded
          to your wallet automatically.
        </p>
        <div className="flex items-center justify-between rounded-md border border-gray-200 px-3 py-2">
          <span>{pluralize(count, 'card')} to be mailed</span>
          <span className="text-base font-semibold tabular-nums">{formatCents(totalCents)}</span>
        </div>
      </div>

      <DialogFooter>
        <Button variant="outline" onClick={() => onOpenChange(false)} disabled={sending}>
          Not yet
        </Button>
        <Button onClick={onConfirm} disabled={sending}>
          {sending ? 'Sending…' : `Yes, mail ${pluralize(count, 'card')}`}
        </Button>
      </DialogFooter>
    </DialogContent>
  </Dialog>
);

/**
 * One failure from `sendHolidayCard`, rendered for what it is.
 *
 * The four the issue calls out need four different next steps, so each gets its
 * own: money gets a top-up link, a stale proof gets a way back to the proof
 * stage, an unmailable recipient names the person, and an unconfigured print
 * partner says plainly that it is our problem and nothing was charged.
 */
const SendFailureNotice: React.FC<{ failure: SendFailure; topUpPath: string }> = ({
  failure,
  topUpPath,
}) => (
  <div
    className={cn(
      'flex items-start gap-2.5 rounded-lg border px-4 py-3 text-sm',
      failure.kind === 'unavailable'
        ? 'border-gray-300 bg-gray-50 text-gray-800'
        : 'border-red-200 bg-red-50 text-red-800'
    )}
  >
    <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
    <div>
      <p>{failure.message}</p>
      {failure.kind === 'shortfall' && (
        <Link
          to={topUpPath}
          className="mt-2 inline-flex items-center rounded-md bg-gray-900 px-3 py-1.5 text-xs font-medium text-white hover:bg-gray-800"
        >
          Add postage
        </Link>
      )}
    </div>
  </div>
);

export default ReviewStage;
