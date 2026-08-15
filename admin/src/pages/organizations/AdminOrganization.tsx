import { useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import { useQuery, useMutation, gql } from '@apollo/client';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Label } from '@/components/ui/label';
import { Badge } from '@/components/ui/badge';
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from '@/components/ui/card';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { Skeleton } from '@/components/ui/skeleton';
import { ArrowLeft, CoinsIcon } from 'lucide-react';
import { toast, Toaster } from 'sonner';
import withAuth from '@/lib/with-auth';
import { OrganizationCredit, OrganizationDetail, OrganizationMembership } from '@/types/app';

const ADMIN_ORGANIZATION_QUERY = gql`
  query AdminOrganization($id: ID!) {
    adminOrganization(id: $id) {
      id
      name
      slug
      description
      membersCount
      creditBalance
      createdAt
      memberships {
        role
        createdAt
        user {
          id
          name
          email
          creditBalance
        }
      }
      credits {
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
`;

const GRANT_ORGANIZATION_CREDITS = gql`
  mutation GrantOrganizationCredits($organizationId: ID!, $amount: Int!) {
    grantOrganizationCredits(input: { organizationId: $organizationId, amount: $amount }) {
      organization {
        id
        creditBalance
      }
      errors
    }
  }
`;

const formatDate = (dateString: string) =>
  new Date(dateString).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });

// The ledger's `reason` column is a database value; give the common ones a
// readable label and fall through to the raw string for anything newer.
const REASON_LABELS: Record<string, string> = {
  purchase: 'Purchase',
  admin_grant: 'Admin grant',
  org_allocation: 'Allocation to member',
  chargeback: 'Chargeback reversal',
};

const reasonLabel = (reason: string | null) => (reason ? (REASON_LABELS[reason] ?? reason) : '—');

function AdminOrganization() {
  const { id } = useParams();
  const [amount, setAmount] = useState('');

  const { data, loading, error, refetch } = useQuery(ADMIN_ORGANIZATION_QUERY, {
    variables: { id },
    fetchPolicy: 'network-only',
  });

  const [grantCredits, { loading: granting }] = useMutation(GRANT_ORGANIZATION_CREDITS);

  const organization: OrganizationDetail | null = data?.adminOrganization ?? null;

  const handleGrant = async (e: React.FormEvent) => {
    e.preventDefault();
    const credits = parseInt(amount, 10);
    if (!Number.isFinite(credits) || credits <= 0) {
      toast.error('Enter a credit amount greater than 0');
      return;
    }

    const { data: result } = await grantCredits({
      variables: { organizationId: id, amount: credits },
    });

    const payload = result.grantOrganizationCredits;
    if (payload.errors.length === 0) {
      toast.success(`Granted ${credits} credits to ${organization?.name}`);
      setAmount('');
      refetch();
    } else {
      toast.error(payload.errors.join(', '));
    }
  };

  const backLink = (
    <Link
      to="/organizations"
      className="inline-flex items-center text-sm text-gray-600 hover:text-black"
    >
      <ArrowLeft className="h-4 w-4 mr-1" />
      All organizations
    </Link>
  );

  if (loading) {
    return (
      <div className="flex flex-col space-y-6">
        {backLink}
        <Skeleton className="h-10 w-64" />
        <Skeleton className="h-40 w-full" />
        <Skeleton className="h-40 w-full" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex flex-col space-y-6">
        {backLink}
        <div className="text-red-500 text-sm bg-red-50 p-3 rounded-md">Error: {error.message}</div>
      </div>
    );
  }

  // Null covers both an unknown id and an organization the customer has since
  // deleted — deleteOrganization is a soft delete, and archived organizations
  // are out of scope for the admin dashboard.
  if (!organization) {
    return (
      <div className="flex flex-col space-y-6">
        {backLink}
        <div className="flex justify-center items-center h-48">
          <p className="text-gray-500 text-lg">Organization not found or deleted</p>
        </div>
      </div>
    );
  }

  const memberships: OrganizationMembership[] = organization.memberships || [];
  const credits: OrganizationCredit[] = organization.credits || [];

  return (
    <div className="flex flex-col space-y-6">
      <Toaster />
      {backLink}

      <div className="flex flex-col sm:flex-row sm:justify-between sm:items-start gap-4">
        <div className="space-y-1">
          <h2 className="text-2xl font-bold text-black">{organization.name}</h2>
          <div className="text-sm text-gray-600 font-mono">{organization.slug}</div>
          {organization.description && (
            <p className="text-sm text-gray-600 max-w-prose">{organization.description}</p>
          )}
          <div className="text-xs text-gray-500">Created {formatDate(organization.createdAt)}</div>
        </div>
        <div className="flex gap-6">
          <div>
            <div className="text-sm text-gray-500">Members</div>
            <div className="text-2xl font-bold text-black">{organization.membersCount}</div>
          </div>
          <div>
            <div className="text-sm text-gray-500">Pool credits</div>
            <div className="text-2xl font-bold text-black">{organization.creditBalance}</div>
          </div>
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <CoinsIcon className="h-5 w-5" />
            Grant credits to pool
          </CardTitle>
          <CardDescription>
            Adds credits to this organization&apos;s shared pool. The grant is recorded on the
            ledger below; correcting one means granting again, not editing history.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleGrant} className="flex flex-col sm:flex-row sm:items-end gap-4">
            <div className="space-y-2 flex-1 max-w-xs">
              <Label htmlFor="grant-amount">Credit amount</Label>
              <Input
                id="grant-amount"
                type="number"
                min="1"
                placeholder="25"
                value={amount}
                onChange={e => setAmount(e.target.value)}
              />
            </div>
            <Button type="submit" disabled={granting}>
              {granting ? 'Granting…' : 'Grant credits'}
            </Button>
          </form>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Members</CardTitle>
          <CardDescription>
            Roles and each member&apos;s own credit balance, which is separate from the shared pool.
          </CardDescription>
        </CardHeader>
        <CardContent className="px-0 sm:px-6">
          {memberships.length === 0 ? (
            <div className="flex justify-center items-center h-24">
              <p className="text-gray-500">No members yet</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Name</TableHead>
                    <TableHead>Email</TableHead>
                    <TableHead>Role</TableHead>
                    <TableHead className="text-center">Personal credits</TableHead>
                    <TableHead>Joined</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {memberships.map(membership => (
                    <TableRow key={membership.user.id}>
                      <TableCell className="font-medium">{membership.user.name}</TableCell>
                      <TableCell className="text-gray-600">{membership.user.email}</TableCell>
                      <TableCell>
                        <Badge variant={membership.role === 'admin' ? 'default' : 'secondary'}>
                          {membership.role}
                        </Badge>
                      </TableCell>
                      <TableCell className="text-center">{membership.user.creditBalance}</TableCell>
                      <TableCell className="text-gray-600 text-sm">
                        {formatDate(membership.createdAt)}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Pool ledger</CardTitle>
          <CardDescription>
            Most recent first. Positive rows put credits into the pool, negative rows took them out.
          </CardDescription>
        </CardHeader>
        <CardContent className="px-0 sm:px-6">
          {credits.length === 0 ? (
            <div className="flex justify-center items-center h-24">
              <p className="text-gray-500">No credit activity yet</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="text-right">Amount</TableHead>
                    <TableHead>Reason</TableHead>
                    <TableHead>By</TableHead>
                    <TableHead>To member</TableHead>
                    <TableHead>Date</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {credits.map(credit => (
                    <TableRow key={credit.id}>
                      <TableCell
                        className={`text-right font-medium ${
                          credit.amount < 0 ? 'text-red-600' : 'text-green-700'
                        }`}
                      >
                        {credit.amount > 0 ? `+${credit.amount}` : credit.amount}
                      </TableCell>
                      <TableCell>{reasonLabel(credit.reason)}</TableCell>
                      {/* An admin grant and a chargeback reversal name nobody
                          here: the ledger resolves people to customer accounts,
                          and neither was caused by one. */}
                      <TableCell className="text-gray-600">{credit.actor?.name ?? '—'}</TableCell>
                      <TableCell className="text-gray-600">{credit.member?.name ?? '—'}</TableCell>
                      <TableCell className="text-gray-600 text-sm">
                        {formatDate(credit.createdAt)}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}

export default withAuth(AdminOrganization);
