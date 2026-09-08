/**
 * Keeping a send in progress alive across a trip to Stripe (#151).
 *
 * Running short of postage mid-flow means leaving the app entirely: Stripe
 * Checkout is a full-page navigation to another origin, and the return URL is
 * fixed on the server (`/buy_postage/success`) — nothing in the round trip
 * carries a hint of what the user was doing when they left. React state does
 * not survive that. A forty-person recipient selection rebuilt by hand is the
 * kind of thing that ends a session, so the selection is written down before
 * the redirect and read back on the way in.
 *
 * `sessionStorage`, matching `lib/credits.ts`: this belongs to *this tab's*
 * trip through Stripe, not to the browser forever. It throws outright in some
 * private-browsing modes, so every access is guarded and losing the note costs
 * only the restored selection, never correctness.
 */
import { EMPTY_SELECTION, type Selection, type SendStage } from './types';

const SELECTION_KEY_PREFIX = 'cardjoy:holiday-card-send:';
const RETURN_TO_KEY = 'cardjoy:postage-return-to';

/** Per card, so two cards in two tabs do not overwrite each other's picks. */
function selectionKey(externalId: string): string {
  return `${SELECTION_KEY_PREFIX}${externalId}`;
}

export interface StoredSendState {
  selection: Selection;
  stage: SendStage;
}

export function rememberSendState(externalId: string, state: StoredSendState): void {
  try {
    sessionStorage.setItem(selectionKey(externalId), JSON.stringify(state));
  } catch {
    // Storage unavailable. The flow still works; it just forgets across a redirect.
  }
}

/**
 * Reads the note back, defensively: it is JSON someone else's code wrote to a
 * store the user can edit, so every field is checked before it becomes state
 * that decides who gets mailed.
 */
export function readSendState(externalId: string): StoredSendState | null {
  try {
    const raw = sessionStorage.getItem(selectionKey(externalId));
    if (!raw) return null;

    const parsed: unknown = JSON.parse(raw);
    if (typeof parsed !== 'object' || parsed === null) return null;

    const { selection, stage } = parsed as Partial<StoredSendState>;
    if (typeof selection !== 'object' || selection === null) return null;

    return {
      selection: {
        listIds: stringArray(selection.listIds),
        contactIds: stringArray(selection.contactIds),
        excludedContactIds: stringArray(selection.excludedContactIds),
      },
      // Someone who left from the payment step to buy postage should come back
      // to the payment step. The stage is only a starting position, not an
      // authorisation: the page demotes a restored `review` the moment the
      // server says the proof is not approved, and sending still needs the
      // confirm dialog either way.
      stage: stage === 'proof' || stage === 'review' ? stage : 'recipients',
    };
  } catch {
    return null;
  }
}

export function clearSendState(externalId: string): void {
  try {
    sessionStorage.removeItem(selectionKey(externalId));
  } catch {
    // See rememberSendState.
  }
}

function stringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.filter((entry): entry is string => typeof entry === 'string');
}

export const emptySendState: StoredSendState = { selection: EMPTY_SELECTION, stage: 'recipients' };

/**
 * Where the postage top-up should send the user afterwards.
 *
 * A path inside this app, never a URL: it is read back out of storage and fed
 * to the router, so accepting an absolute URL would make an open redirect out
 * of a value the page itself wrote.
 */
export function rememberPostageReturnTo(path: string): void {
  try {
    sessionStorage.setItem(RETURN_TO_KEY, path);
  } catch {
    // See rememberSendState.
  }
}

/** The stored path, or null. Anything that is not an app-relative path is dropped. */
export function readPostageReturnTo(): string | null {
  try {
    const value = sessionStorage.getItem(RETURN_TO_KEY);
    if (!value) return null;
    // Single leading slash only: "//evil.example" is a protocol-relative URL
    // that a router would happily leave the site for.
    return /^\/[^/]/.test(value) ? value : null;
  } catch {
    return null;
  }
}

export function clearPostageReturnTo(): void {
  try {
    sessionStorage.removeItem(RETURN_TO_KEY);
  } catch {
    // See rememberSendState.
  }
}
