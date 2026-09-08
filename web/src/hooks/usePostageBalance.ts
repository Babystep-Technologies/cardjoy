/**
 * The postage balance, read the same way everywhere (#152).
 *
 * The balance shows up in three places — the wallet page, the send flow's
 * review stage, and the user menu — and they must never disagree. Apollo
 * normalises `User` by id, so every caller of this hook reads the same cache
 * entry: a top-up that updates one updates all of them, without anything
 * passing a number down through props.
 *
 * Deliberately not part of `AuthContext`. That holds a decoded JWT, which is
 * signed at sign-in and frozen thereafter — a balance baked into a token would
 * be stale from the first card the user mailed.
 */
import { gql, useQuery } from '@apollo/client';
import { useAuth } from '@/contexts/AuthContext';

export const POSTAGE_BALANCE = gql`
  query PostageBalance {
    viewer {
      id
      postageBalanceCents
    }
  }
`;

interface PostageBalanceResponse {
  viewer: { id: string; postageBalanceCents: number } | null;
}

export interface PostageBalance {
  /** Signed integer US cents. Negative is a real, displayable state. */
  balanceCents: number;
  /** True until the first answer arrives, so callers can hold off on a number. */
  loading: boolean;
  /** A chargeback can leave the wallet owing money; sending is blocked until it is topped up. */
  overdrawn: boolean;
}

export function usePostageBalance(): PostageBalance {
  const { user } = useAuth();
  // Nothing to ask for when signed out, and asking would 401 the whole request.
  const { data, loading } = useQuery<PostageBalanceResponse>(POSTAGE_BALANCE, {
    skip: !user,
    fetchPolicy: 'cache-first',
  });

  const balanceCents = data?.viewer?.postageBalanceCents ?? 0;

  return {
    balanceCents,
    loading: loading && !data,
    overdrawn: balanceCents < 0,
  };
}
