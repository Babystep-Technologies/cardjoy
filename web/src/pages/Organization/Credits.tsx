import { useEffect, useState } from 'react';
import { gql, useMutation, useQuery } from '@apollo/client';
import { Link } from 'react-router-dom';
import { Building2, Coins, LoaderCircle } from 'lucide-react';
import { Toaster, toast } from 'sonner';
import withAuth from '@/lib/with-auth';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { CREDIT_PLANS } from '@/lib/constants';
import {
  clearOrganizationCheckout,
  isInsufficientCreditsError,
  readOrganizationCheckout,
  rememberOrganizationCheckout,
} from '@/lib/credits';
import { useOrganization } from '@/contexts/OrganizationContext';

/**
 * The organization's shared credit pool: what it holds, where it came from, and — for an admin —
 * how to top it up and hand credits to the people who need them.
 *
 * Allocation is a *transfer*, not a shared wallet: the credits become the member's own and are
 * spent from their personal balance, and there is no clawing them back. The copy on this page says
 * so in as many places as it takes, because an admin who assumes otherwise finds out the expensive
 * way.
 *
 * Scoped to the active organization rather than addressed by id, like the other organization pages.
 * Buying and allocating are admin-only on the server; a member gets the balance and nothing else,
 * since knowing what the pool holds isn't the same as being able to spend it.
 */

const ORGANIZATION_CREDITS = gql`
  query OrganizationCredits($isAdmin: Boolean!) {
    viewer {
      id
      creditBalance
      activeOrganization {
        id
        name
        creditBalance
        memberships @include(if: $isAdmin) {
          id
          role
          user {
            id
            name
            email
            creditBalance
          }
        }
        credits @include(if: $isAdmin) {
          id
          amount
          reason
          createdAt
          actor {
            id
            name
          }
          member {
            id
            name
          }
        }
      }
    }
  }
`;

const CREATE_STRIPE_CHECKOUT_SESSION = gql`
  mutation CreateStripeCheckoutSession($input: CreateStripeCheckoutSessionInput!) {
    createStripeCheckoutSession(input: $input) {
      checkoutUrl
      error
    }
  }
`;

// The payload carries both sides of the transfer, and Apollo normalizes them into the cache by id,
// so the pool balance and the member's balance on screen update from the response itself.
const ALLOCATE_ORGANIZATION_CREDITS = gql`
  mutation AllocateOrganizationCredits($input: AllocateOrganizationCreditsInput!) {
    allocateOrganizationCredits(input: $input) {
      organization {
        id
        creditBalance
      }
      member {
        id
        creditBalance
      }
      errors
    }
  }
`;

type Membership = {
  id: string;
  role: string;
  user: { id: string; name: string; email: string; creditBalance: number };
};

type LedgerEntry = {
  id: string;
  amount: number;
  reason: string | null;
  createdAt: string;
  actor: { id: string; name: string } | null;
  member: { id: string; name: string } | null;
};

type CreditsData = {
  viewer: {
    id: string;
    creditBalance: number;
    activeOrganization: {
      id: string;
      name: string;
      creditBalance: number;
      memberships?: Membership[];
      credits?: LedgerEntry[];
    } | null;
  } | null;
};

/** How long to keep asking for the balance after a return from Stripe, and how often. */
const POLL_INTERVAL_MS = 3000;
const POLL_TIMEOUT_MS = 45000;

const formatDate = (iso: string) =>
  new Date(iso).toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' });

const pluralCredits = (amount: number) =>
  `${amount} ${Math.abs(amount) === 1 ? 'credit' : 'credits'}`;

/** A ledger row in words. `reason` is the backend's, and unknown ones still read as something. */
const describeEntry = (entry: LedgerEntry): string => {
  const actor = entry.actor?.name;

  switch (entry.reason) {
    case 'purchase':
      return actor ? `Purchased by ${actor}` : 'Purchased';
    case 'org_allocation':
      return entry.member
        ? `Allocated to ${entry.member.name}${actor ? ` by ${actor}` : ''}`
        : 'Allocated to a member';
    case 'chargeback':
      return 'Reversed after a chargeback';
    case 'admin_grant':
      return 'Granted by CardJoy';
    default:
      return entry.reason ? entry.reason.replace(/_/g, ' ') : 'Adjustment';
  }
};

const errorList = (errors: string[]) =>
  errors.length > 0 && (
    <ul className="space-y-1 text-sm font-medium text-red-600">
      {errors.map(error => (
        <li key={error}>{error}</li>
      ))}
    </ul>
  );

const OrganizationCreditsPage: React.FC = () => {
  const { activeOrganization, loading: organizationLoading } = useOrganization();
  const isAdmin = activeOrganization?.role === 'admin';

  const { data, loading, refetch, startPolling, stopPolling } = useQuery<CreditsData>(
    ORGANIZATION_CREDITS,
    {
      variables: { isAdmin },
      fetchPolicy: 'cache-and-network',
      skip: !activeOrganization,
    }
  );

  const organization = data?.viewer?.activeOrganization ?? null;
  const personalBalance = data?.viewer?.creditBalance ?? null;
  const poolBalance = organization?.creditBalance ?? null;
  const memberships = organization?.memberships ?? [];
  const ledger = organization?.credits ?? [];

  const [createCheckoutSession] = useMutation(CREATE_STRIPE_CHECKOUT_SESSION);
  const [allocateCredits] = useMutation(ALLOCATE_ORGANIZATION_CREDITS);

  const [selectedPlan, setSelectedPlan] = useState(CREDIT_PLANS[0]);
  const [redirecting, setRedirecting] = useState(false);
  const [purchaseErrors, setPurchaseErrors] = useState<string[]>([]);

  const [amounts, setAmounts] = useState<Record<string, string>>({});
  const [busyUserId, setBusyUserId] = useState<string | null>(null);
  const [allocationErrors, setAllocationErrors] = useState<string[]>([]);

  // The pool balance we left for Stripe with, while we wait for the webhook to move it. Null the
  // rest of the time, which is when this page does not poll.
  const [balanceBeforeCheckout, setBalanceBeforeCheckout] = useState<number | null>(null);

  // Coming back from checkout. The success page sends the admin here, but the credit only lands
  // when Stripe's webhook reaches us, which is usually a second or two after the redirect.
  useEffect(() => {
    if (!activeOrganization) return;

    const pending = readOrganizationCheckout();
    if (!pending || pending.organizationId !== activeOrganization.id) return;

    clearOrganizationCheckout();
    setBalanceBeforeCheckout(pending.balanceBefore);
  }, [activeOrganization]);

  useEffect(() => {
    if (balanceBeforeCheckout === null || poolBalance === null) return;

    // The webhook landed — or the balance had already moved before we looked.
    if (poolBalance !== balanceBeforeCheckout) {
      setBalanceBeforeCheckout(null);
      return;
    }

    startPolling(POLL_INTERVAL_MS);
    const giveUp = setTimeout(() => setBalanceBeforeCheckout(null), POLL_TIMEOUT_MS);

    return () => {
      stopPolling();
      clearTimeout(giveUp);
    };
  }, [balanceBeforeCheckout, poolBalance, startPolling, stopPolling]);

  const handleCheckout = async () => {
    if (!organization) return;

    setPurchaseErrors([]);
    setRedirecting(true);

    try {
      const { data: result } = await createCheckoutSession({
        variables: {
          input: { priceId: selectedPlan.priceId, organizationId: organization.id },
        },
      });
      const payload = result?.createStripeCheckoutSession;

      if (payload?.error || !payload?.checkoutUrl) {
        setPurchaseErrors([payload?.error ?? 'Could not start the checkout.']);
        return;
      }

      // Written before the redirect, because after it this tab belongs to Stripe.
      rememberOrganizationCheckout({
        organizationId: organization.id,
        organizationName: organization.name,
        balanceBefore: organization.creditBalance,
      });
      window.location.href = payload.checkoutUrl;
    } catch (error) {
      setPurchaseErrors([error instanceof Error ? error.message : 'Could not start the checkout.']);
    } finally {
      setRedirecting(false);
    }
  };

  const handleAllocate = async (membership: Membership, event: React.FormEvent) => {
    event.preventDefault();
    if (!organization) return;

    const amount = Number(amounts[membership.user.id]);
    if (!Number.isInteger(amount) || amount <= 0) {
      setAllocationErrors(['Enter a whole number of credits above zero.']);
      return;
    }

    setAllocationErrors([]);
    setBusyUserId(membership.user.id);

    try {
      const { data: result } = await allocateCredits({
        variables: {
          input: { organizationId: organization.id, userId: membership.user.id, amount },
        },
      });
      const errors: string[] = result?.allocateOrganizationCredits?.errors ?? [];

      if (errors.length > 0) {
        // The pool version of the shortfall the rest of the app routes to /buy_credits for. Here
        // the fix is on this page, so say that instead of sending an admin to buy personally.
        setAllocationErrors(
          isInsufficientCreditsError(errors)
            ? [...errors, 'Top the pool up above, then try again.']
            : errors
        );
        return;
      }

      // Only now: the input still holds what the admin typed if the transfer was refused.
      setAmounts(current => ({ ...current, [membership.user.id]: '' }));
      toast.success(`${pluralCredits(amount)} are now ${membership.user.name}'s to spend.`);
      // The balances come back in the payload; the ledger has to be re-read.
      await refetch();
    } catch (error) {
      setAllocationErrors([
        error instanceof Error ? error.message : 'Could not allocate the credits.',
      ]);
    } finally {
      setBusyUserId(null);
    }
  };

  if (organizationLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <LoaderCircle className="h-6 w-6 animate-spin text-gray-400" />
      </div>
    );
  }

  // Personal is a real context, not a missing organization — say so rather than 404ing.
  if (!activeOrganization) {
    return (
      <div className="mx-auto max-w-2xl px-4 pt-20 pb-12 text-center">
        <Building2 className="mx-auto h-10 w-10 text-gray-400" />
        <h1 className="mt-4 text-2xl font-bold text-black">No organization selected</h1>
        <p className="mt-2 text-gray-600">
          You're working in your personal context, where credits are just yours. Switch to an
          organization from the header to see its shared pool.
        </p>
        <div className="mt-6 flex flex-wrap justify-center gap-3">
          <Button asChild>
            <Link to="/organizations/new">Create an organization</Link>
          </Button>
          <Button asChild variant="outline">
            <Link to="/buy_credits">Buy personal credits</Link>
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-5xl px-4 pt-12 pb-16">
      <Toaster />

      <header className="space-y-2">
        <h1 className="text-3xl font-bold text-black">Credits</h1>
        <p className="text-gray-600">
          {activeOrganization.name}'s shared pool. Credits allocated from it become the member's own
          — they're spent from that person's personal balance, and they can't be taken back.
        </p>
      </header>

      {loading && !organization ? (
        <div className="flex justify-center py-16">
          <LoaderCircle className="h-6 w-6 animate-spin text-gray-400" />
        </div>
      ) : (
        <div className="mt-8 space-y-8">
          <Card>
            <CardHeader>
              <CardTitle>Pool balance</CardTitle>
              <CardDescription>
                What {activeOrganization.name} has left to hand out.
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-2">
              <p className="flex items-center gap-3 text-4xl font-bold text-black">
                <Coins className="h-8 w-8 text-[var(--color-brand-yellow)]" />
                {poolBalance ?? 0}
                <span className="text-base font-medium text-gray-500">
                  {Math.abs(poolBalance ?? 0) === 1 ? 'credit' : 'credits'}
                </span>
              </p>
              {personalBalance !== null && (
                <p className="text-sm text-gray-600">
                  Your own balance is {pluralCredits(personalBalance)}, separate from the pool.
                </p>
              )}
              {balanceBeforeCheckout !== null && (
                <p className="flex items-center gap-2 text-sm text-gray-600">
                  <LoaderCircle className="h-4 w-4 animate-spin text-gray-400" />
                  Waiting for your payment to settle — this updates on its own.
                </p>
              )}
              {!isAdmin && (
                <p className="rounded-md bg-gray-50 px-3 py-2 text-sm text-gray-600">
                  You're a member of this organization, so this page is read-only. Ask an admin to
                  allocate credits to you; once they do, the credits are yours to spend.
                </p>
              )}
            </CardContent>
          </Card>

          {isAdmin && (
            <Card>
              <CardHeader>
                <CardTitle>Buy credits for the pool</CardTitle>
                <CardDescription>
                  Paid for once, by you, into {activeOrganization.name}'s pool rather than your
                  personal balance.
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-5">
                <div className="grid gap-4 md:grid-cols-3">
                  {CREDIT_PLANS.map(plan => {
                    const isSelected = selectedPlan.title === plan.title;

                    return (
                      <button
                        key={plan.title}
                        type="button"
                        aria-pressed={isSelected}
                        onClick={() => setSelectedPlan(plan)}
                        className={`rounded-lg border p-4 text-left transition ${
                          isSelected
                            ? 'border-black shadow-sm'
                            : 'border-gray-200 hover:border-gray-300'
                        }`}
                      >
                        <p className="font-semibold text-gray-900">{plan.title}</p>
                        <p className="mt-1 text-2xl font-bold text-black">{plan.price}</p>
                        <p className="text-sm text-gray-600">{plan.credits}</p>
                      </button>
                    );
                  })}
                </div>

                {errorList(purchaseErrors)}

                <Button type="button" disabled={redirecting} onClick={handleCheckout}>
                  {redirecting && <LoaderCircle className="h-4 w-4 animate-spin" />}
                  {redirecting ? 'Redirecting...' : `Buy ${selectedPlan.credits}`}
                </Button>
              </CardContent>
            </Card>
          )}

          {isAdmin && (
            <Card>
              <CardHeader>
                <CardTitle>Allocate to a member</CardTitle>
                <CardDescription>
                  Moving credits out of the pool gives them away: they become that member's own, to
                  spend on whatever they like. There's no way to take them back.
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <ul className="divide-y divide-gray-100">
                  {memberships.map(membership => {
                    const busy = busyUserId === membership.user.id;

                    return (
                      <li key={membership.id} className="py-3 first:pt-0 last:pb-0">
                        <form
                          onSubmit={event => handleAllocate(membership, event)}
                          className="flex flex-wrap items-center gap-3"
                        >
                          <div className="min-w-0 flex-1">
                            <p className="flex items-center gap-2 font-medium text-gray-900">
                              <span className="truncate">{membership.user.name}</span>
                              {membership.role === 'admin' && (
                                <Badge variant="outline" className="shrink-0">
                                  Admin
                                </Badge>
                              )}
                            </p>
                            <p className="truncate text-sm text-gray-600">
                              {membership.user.email}
                            </p>
                            <p className="text-xs text-gray-500">
                              Has {pluralCredits(membership.user.creditBalance)}
                            </p>
                          </div>

                          <div className="flex items-center gap-2">
                            <Label
                              htmlFor={`allocate-${membership.user.id}`}
                              className="sr-only"
                            >{`Credits to allocate to ${membership.user.name}`}</Label>
                            <Input
                              id={`allocate-${membership.user.id}`}
                              type="number"
                              min={1}
                              step={1}
                              inputMode="numeric"
                              placeholder="0"
                              className="w-24"
                              value={amounts[membership.user.id] ?? ''}
                              onChange={event =>
                                setAmounts(current => ({
                                  ...current,
                                  [membership.user.id]: event.target.value,
                                }))
                              }
                            />
                            <Button type="submit" variant="outline" disabled={busy}>
                              {busy && <LoaderCircle className="h-4 w-4 animate-spin" />}
                              Allocate
                            </Button>
                          </div>
                        </form>
                      </li>
                    );
                  })}
                </ul>

                {errorList(allocationErrors)}
              </CardContent>
            </Card>
          )}

          {isAdmin && (
            <Card>
              <CardHeader>
                <CardTitle>History</CardTitle>
                <CardDescription>
                  Every credit into and out of the pool, newest first.
                </CardDescription>
              </CardHeader>
              <CardContent>
                {ledger.length === 0 ? (
                  <p className="text-sm text-gray-500">
                    Nothing yet. Buying credits for the pool is the first line.
                  </p>
                ) : (
                  <ul className="divide-y divide-gray-100">
                    {ledger.map(entry => (
                      <li
                        key={entry.id}
                        className="flex flex-wrap items-center gap-3 py-3 first:pt-0 last:pb-0"
                      >
                        <div className="min-w-0 flex-1">
                          <p className="truncate font-medium text-gray-900">
                            {describeEntry(entry)}
                          </p>
                          <p className="text-xs text-gray-500">{formatDate(entry.createdAt)}</p>
                        </div>
                        <span
                          className={`font-semibold tabular-nums ${
                            entry.amount < 0 ? 'text-gray-600' : 'text-green-600'
                          }`}
                        >
                          {entry.amount > 0 ? `+${entry.amount}` : entry.amount}
                        </span>
                      </li>
                    ))}
                  </ul>
                )}
              </CardContent>
            </Card>
          )}
        </div>
      )}
    </div>
  );
};

export default withAuth(OrganizationCreditsPage);
