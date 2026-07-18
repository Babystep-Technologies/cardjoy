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
