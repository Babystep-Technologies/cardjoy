// Mirrors the backend's Mutations::BaseMutation::INSUFFICIENT_CREDITS_ERROR.
// Keep this string in sync with api/app/graphql/mutations/base_mutation.rb.
export const INSUFFICIENT_CREDITS_ERROR = 'Not enough credits';

type MutationError = string | { message?: string | null } | null | undefined;

// True when a mutation's `errors` array signals the user ran out of credits,
// so the caller can route them to /buy_credits instead of just toasting.
export function isInsufficientCreditsError(errors?: MutationError[] | null): boolean {
  if (!errors) return false;
  return errors.some(error => {
    const message = typeof error === 'string' ? error : (error?.message ?? '');
    return message.includes(INSUFFICIENT_CREDITS_ERROR);
  });
}

export const INSUFFICIENT_CREDITS_REDIRECT = '/buy_credits?reason=insufficient_balance';

/**
 * A checkout that is buying into an organization's pool rather than a personal balance.
 *
 * Stripe's success URL is fixed on the server (`/buy_credits/success`), so nothing in the round
 * trip tells the app the money was headed for a pool. This note, written just before the redirect
 * and read on the way back, is what lets the success page say where the credits landed and the
 * credits page know to wait for the webhook — `balanceBefore` is what it waits for a change from.
 *
 * sessionStorage rather than localStorage: it belongs to this tab's trip through Stripe, and it
 * throws in some private-browsing modes, so every access is guarded. Losing the note only costs
 * the nicer copy and the auto-refresh.
 */
const ORGANIZATION_CHECKOUT_KEY = 'cardjoy:organization-checkout';

export type OrganizationCheckout = {
  organizationId: string;
  organizationName: string;
  balanceBefore: number;
};

export function rememberOrganizationCheckout(checkout: OrganizationCheckout): void {
  try {
    sessionStorage.setItem(ORGANIZATION_CHECKOUT_KEY, JSON.stringify(checkout));
  } catch {
    // Storage unavailable — the flow still works, it just comes back less informed.
  }
}

export function readOrganizationCheckout(): OrganizationCheckout | null {
  try {
    const raw = sessionStorage.getItem(ORGANIZATION_CHECKOUT_KEY);
    if (!raw) return null;

    const parsed: unknown = JSON.parse(raw);
    if (typeof parsed !== 'object' || parsed === null) return null;

    const { organizationId, organizationName, balanceBefore } = parsed as OrganizationCheckout;
    if (typeof organizationId !== 'string' || typeof balanceBefore !== 'number') return null;

    return { organizationId, organizationName: String(organizationName ?? ''), balanceBefore };
  } catch {
    return null;
  }
}

export function clearOrganizationCheckout(): void {
  try {
    sessionStorage.removeItem(ORGANIZATION_CHECKOUT_KEY);
  } catch {
    // See rememberOrganizationCheckout.
  }
}
