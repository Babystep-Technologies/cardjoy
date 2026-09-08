/**
 * The postage wallet's vocabulary (#152).
 *
 * Two things live here because two pages need them and neither should own the
 * other: how a ledger row is described to a human, and the note that survives
 * the trip to Stripe.
 *
 * ## Never the word "credits"
 *
 * CardJoy already sells *credits* — whole units, one per digital card. This
 * wallet is integer US cents and buys paper and stamps. A user who confuses the
 * two has paid for something they cannot use, so nothing here reads "credit",
 * "balance of 5", or anything else countable. It is a dollar amount, and it is
 * always formatted as one by `formatCents`.
 */

/**
 * What a ledger row says to the person who earned it.
 *
 * The API sends `eventKind` — `postage_spent_on_mail` — plus a `reason` slug
 * like `holiday_card_mail`. Neither is English, and showing either one raw is
 * how a wallet becomes unauditable. Mapping happens here, on the client, because
 * the server's kinds are an enum for the ledger's integrity, not display copy.
 *
 * One row is one movement of money: the send flow writes a row per piece of
 * mail, so four cards is four rows of a dollar or so each rather than one
 * summarised line. That is deliberate — the ledger should reconcile against the
 * bank, and a row the user can tie to a specific card is what makes a surprise
 * charge explicable.
 */
const EVENT_KIND_DESCRIPTIONS: Record<string, string> = {
  postage_purchased: 'Postage added',
  postage_spent_on_mail: 'Card printed and mailed',
  postage_refunded: 'Refund — card was not mailed',
  postage_promo_grant: 'Promotional postage',
  postage_reversed_due_to_chargeback: 'Reversed after a disputed payment',
  postage_admin_adjustment: 'Adjustment by CardJoy support',
};

/**
 * A human description for a ledger row.
 *
 * Falls back rather than failing: a kind added to the server before this map
 * knows about it still gets a readable line from its `reason` slug, and a row
 * with neither still renders — with its amount, which is the part that has to
 * be right. An unlabelled row is a nuisance; a missing row is a wallet that
 * does not add up.
 */
export function describeLedgerEntry(
  eventKind: string | null | undefined,
  reason: string | null | undefined
): string {
  if (eventKind && EVENT_KIND_DESCRIPTIONS[eventKind]) return EVENT_KIND_DESCRIPTIONS[eventKind];

  const slug = eventKind ?? reason;
  if (!slug) return 'Wallet activity';

  // "holiday_card_mail_refund" → "Holiday card mail refund". Not as good as a
  // written string, but honest and readable, which beats showing the slug.
  const words = slug
    .replace(/^postage_/, '')
    .replace(/_/g, ' ')
    .trim();
  if (!words) return 'Wallet activity';
  return words.charAt(0).toUpperCase() + words.slice(1);
}

/**
 * What the user was doing before they went to Stripe.
 *
 * Stripe's return URL is fixed on the server (`/buy_postage/success`) and
 * carries only a session id, so the round trip forgets everything else. Two
 * things are worth remembering:
 *
 * - `balanceBefore`, because the wallet is credited by the
 *   `checkout.session.completed` webhook, *not* by the redirect. Stripe sends
 *   the user back the instant they pay and the webhook lands a beat later, so a
 *   success page that reads the balance immediately shows the old number and
 *   reads as a failed payment. Knowing the number to expect a change *from* is
 *   what turns that into an honest "still landing…" instead.
 * - `topUpCents`, so the page can name what is arriving.
 *
 * `sessionStorage`, matching `lib/credits.ts`: this belongs to this tab's trip
 * through Stripe. It throws outright in some private-browsing modes, so every
 * access is guarded — losing the note costs the nicer copy and nothing else,
 * since the balance itself is the server's and is re-read either way.
 */
const POSTAGE_CHECKOUT_KEY = 'cardjoy:postage-checkout';

export type PostageCheckout = {
  balanceBefore: number;
  topUpCents: number;
};

export function rememberPostageCheckout(checkout: PostageCheckout): void {
  try {
    sessionStorage.setItem(POSTAGE_CHECKOUT_KEY, JSON.stringify(checkout));
  } catch {
    // Storage unavailable — the flow still works, it just comes back less informed.
  }
}

export function readPostageCheckout(): PostageCheckout | null {
  try {
    const raw = sessionStorage.getItem(POSTAGE_CHECKOUT_KEY);
    if (!raw) return null;

    const parsed: unknown = JSON.parse(raw);
    if (typeof parsed !== 'object' || parsed === null) return null;

    const { balanceBefore, topUpCents } = parsed as Partial<PostageCheckout>;
    // Both must be real numbers: these drive "has the money landed yet",
    // and a NaN from hand-edited storage would make that comparison
    // silently false forever.
    if (!Number.isFinite(balanceBefore) || !Number.isFinite(topUpCents)) return null;

    return { balanceBefore: Number(balanceBefore), topUpCents: Number(topUpCents) };
  } catch {
    return null;
  }
}

export function clearPostageCheckout(): void {
  try {
    sessionStorage.removeItem(POSTAGE_CHECKOUT_KEY);
  } catch {
    // See rememberPostageCheckout.
  }
}
