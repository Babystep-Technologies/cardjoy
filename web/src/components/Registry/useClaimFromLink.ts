import { useEffect, useState } from 'react';
import { gql, useApolloClient } from '@apollo/client';
import { useSearchParams } from 'react-router-dom';
import { getWishListReservationTokenKey } from '@/lib/utils';

// Named to match GraphqlController::PUBLIC_OPERATIONS so a guest can run it signed out.
const GET_WISH_LIST_CLAIM = gql`
  query GetWishListClaim($token: String!) {
    wishListClaim(token: $token) {
      wishListItemId
      purchased
    }
  }
`;

/**
 * The "manage my claim" link in a guest's email carries `?claim=<token>`. Items remember a claim by
 * keeping its token in this browser, so a guest opening the link on another device would see
 * nothing of their own. This copies the claim into local storage before the items render, then
 * reports `ready` so the page can wait for it.
 *
 * Always resolves to `ready`: a bad or stale token just means nothing is restored.
 */
export function useClaimFromLink(): { ready: boolean } {
  const [params, setParams] = useSearchParams();
  const client = useApolloClient();
  const token = params.get('claim');
  const [ready, setReady] = useState(!token);

  useEffect(() => {
    if (!token) return;
    let cancelled = false;

    client
      .query({ query: GET_WISH_LIST_CLAIM, variables: { token }, fetchPolicy: 'network-only' })
      .then(({ data }) => {
        const claim = data?.wishListClaim;
        if (!claim) return;
        const key = getWishListReservationTokenKey(String(claim.wishListItemId));
        try {
          localStorage.setItem(key, token);
          if (claim.purchased) localStorage.setItem(`${key}:purchased`, '1');
          else localStorage.removeItem(`${key}:purchased`);
        } catch {
          // Storage can be unavailable (private windows); the page still works without it.
        }
      })
      .catch(() => {})
      .finally(() => {
        if (cancelled) return;
        // Drop the token from the address bar so it isn't shared along with the page link.
        const next = new URLSearchParams(params);
        next.delete('claim');
        setParams(next, { replace: true });
        setReady(true);
      });

    return () => {
      cancelled = true;
    };
    // Run once per token; `params`/`setParams` change as a result of this very effect.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token]);

  return { ready };
}
