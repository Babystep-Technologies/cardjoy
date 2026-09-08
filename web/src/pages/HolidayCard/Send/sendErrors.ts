/**
 * Telling `sendHolidayCard`'s failures apart (#151).
 *
 * The mutation returns `errors: [String]` — sentences, not codes — so this file
 * matches on the strings `Mutations::SendHolidayCard` defines as constants.
 * That is a real coupling and it is written down here rather than discovered in
 * production: **keep these in sync with
 * `api/app/graphql/mutations/send_holiday_card.rb`**, the same arrangement
 * `lib/credits.ts` has with `BaseMutation::INSUFFICIENT_CREDITS_ERROR`.
 *
 * It matters because these four failures need four different things from the
 * user — money, a new proof, a fixed address, and patience — and a generic
 * toast asks for none of them. Anything unrecognised falls through as itself
 * rather than being flattened into "something went wrong": an unmatched
 * sentence from the server is still a sentence written for a human.
 */
import { formatCents } from '@/lib/money';

// Mirrors Mutations::SendHolidayCard::NO_PROOF_ERROR / STALE_PROOF_ERROR.
const NO_PROOF_FRAGMENT = 'Approve a proof of this card before sending it';
const STALE_PROOF_FRAGMENT = 'has changed since its proof was approved';
// Mirrors Mutations::SendHolidayCard::UNAVAILABLE_ERROR.
const UNAVAILABLE_FRAGMENT = 'Sending cards by post is unavailable';
// Mirrors SendHolidayCard#check_balance!, which spells the amounts in cents.
const SHORTFALL_FRAGMENT = 'Not enough postage';
const NO_RECIPIENTS_FRAGMENT = 'Pick at least one recipient';

export type SendFailureKind =
  | 'shortfall'
  | 'stale_proof'
  | 'unmailable_recipient'
  | 'unavailable'
  | 'no_recipients'
  | 'unknown';

export interface SendFailure {
  kind: SendFailureKind;
  /** What to put in front of the user. Already in dollars where money is involved. */
  message: string;
  /** For `shortfall` only: how much more postage is needed, in integer cents. */
  shortfallCents?: number;
}

/**
 * The server's shortfall sentence names three amounts in cents, in order:
 * cost, balance, shortfall. We re-render them in dollars rather than showing a
 * user the phrase "3200 cents", and we need the shortfall as a number anyway to
 * size the top-up.
 */
const SHORTFALL_AMOUNTS = /costs (\d+) cents and your wallet has (\d+) cents — you're (\d+) cents/;

function shortfallFrom(message: string): SendFailure {
  const match = SHORTFALL_AMOUNTS.exec(message);
  if (!match) {
    // The sentence moved. Still a shortfall, still routes to the top-up — it
    // just cannot size it, which is better than mis-stating an amount.
    return { kind: 'shortfall', message: 'You do not have enough postage for this send.' };
  }

  const [, totalCents, balanceCents, shortfallCents] = match.map(Number);
  return {
    kind: 'shortfall',
    shortfallCents,
    message:
      `This send costs ${formatCents(totalCents)} and your postage wallet has ` +
      `${formatCents(balanceCents)} — you are ${formatCents(shortfallCents)} short.`,
  };
}

export function classifySendError(message: string): SendFailure {
  if (message.includes(SHORTFALL_FRAGMENT)) return shortfallFrom(message);

  if (message.includes(STALE_PROOF_FRAGMENT) || message.includes(NO_PROOF_FRAGMENT)) {
    return {
      kind: 'stale_proof',
      message:
        'This card changed after its proof was approved, so nothing was sent and nothing was ' +
        'charged. Generate a new proof and approve it.',
    };
  }

  if (message.includes(UNAVAILABLE_FRAGMENT)) {
    return {
      kind: 'unavailable',
      message:
        'Mailing printed cards is unavailable right now — this is on our side, not yours. ' +
        'Nothing was sent and nothing was charged. Please try again shortly.',
    };
  }

  if (message.includes(NO_RECIPIENTS_FRAGMENT)) {
    return { kind: 'no_recipients', message: 'Pick at least one recipient before sending.' };
  }

  // Every unsendable recipient comes back as "<name>: <reason>" (see
  // SendHolidayCard#recipient_errors) — an address that stopped being
  // deliverable between the quote and the send. Named, so the user can go and
  // fix the right one.
  if (/^[^:]+: .+/.test(message)) {
    return {
      kind: 'unmailable_recipient',
      message,
    };
  }

  return { kind: 'unknown', message };
}

export function classifySendErrors(errors: string[]): SendFailure[] {
  return errors.map(classifySendError);
}

/** The one to lead with when several came back at once: money first, then blockers. */
const KIND_PRIORITY: SendFailureKind[] = [
  'shortfall',
  'stale_proof',
  'unavailable',
  'unmailable_recipient',
  'no_recipients',
  'unknown',
];

export function primaryFailure(failures: SendFailure[]): SendFailure | null {
  for (const kind of KIND_PRIORITY) {
    const match = failures.find(failure => failure.kind === kind);
    if (match) return match;
  }
  return null;
}
