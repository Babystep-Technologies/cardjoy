/**
 * Telling apart the ways loading a holiday card can fail.
 *
 * The editor and the send flow both open a card by fetching it alongside the
 * template/sticker/options catalogue in one round trip. Before this, both
 * collapsed every failure into "We could not find that card" — which was a lie
 * for all but one of them, and an actively misleading one: a client whose query
 * had drifted from the schema, an invalidated session, and a dropped connection
 * all reported a card that was perfectly fine as missing.
 *
 * Three outcomes are worth separating, because the user's next move differs for
 * each: sign in again, retry, or accept the card is gone.
 */
import type { ApolloError } from '@apollo/client';

/**
 * The session is no longer good, so retrying achieves nothing — only a fresh
 * sign-in will.
 *
 * Both shapes the API can answer with are checked, mirroring the conditions
 * `lib/apollo-client.ts` already acts on. `GraphqlController` rejects an
 * unauthenticated non-public operation with a bare HTTP 401 before GraphQL runs
 * at all, while `Queries::HolidayCard` raises `NOT_AUTHENTICATED_ERROR` from
 * inside a request that reached the schema.
 */
export function isAuthFailure(error?: ApolloError): boolean {
  if (!error) return false;

  const networkError = error.networkError as { statusCode?: number } | null;
  if (networkError?.statusCode === 401) return true;

  return error.graphQLErrors.some(
    graphQLError =>
      graphQLError.extensions?.code === 'UNAUTHENTICATED' ||
      graphQLError.message === 'Unauthorized' ||
      graphQLError.message === 'Not authenticated'
  );
}

/**
 * The `holidayCard` field itself errored, so a null card is a failure rather
 * than an absence.
 *
 * This only matters under `errorPolicy: 'all'`, which is what lets a partial
 * response through in the first place. Without the path check, a card that
 * failed to resolve would be indistinguishable from one that resolved to null
 * because it does not exist — and we would be back to the same lie in a
 * narrower case.
 */
export function cardFieldErrored(error?: ApolloError): boolean {
  return Boolean(
    error?.graphQLErrors.some(graphQLError => graphQLError.path?.[0] === 'holidayCard')
  );
}
