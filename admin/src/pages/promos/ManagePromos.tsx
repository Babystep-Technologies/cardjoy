import { useState } from 'react';
import { useQuery, useMutation, gql } from '@apollo/client';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Label } from '@/components/ui/label';
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
import { ChevronLeft, ChevronRight, Gift, UserPlus } from 'lucide-react';
import { toast, Toaster } from 'sonner';
import withAuth from '@/lib/with-auth';
import { PromoCode } from '@/types/app';

const ADMIN_PROMO_CODES_QUERY = gql`
  query AdminPromoCodes($page: Int, $perPage: Int) {
    adminPromoCodes(page: $page, perPage: $perPage) {
      promoCodes {
        id
        code
        creditAmount
        usageLimit
        timesRedeemed
        expiresAt
        createdAt
        user {
          id
          email
        }
      }
      totalCount
      page
      perPage
      totalPages
    }
  }
`;

const ISSUE_USER_PROMO_CODE = gql`
  mutation IssueUserPromoCode(
    $email: String!
    $creditAmount: Int!
    $code: String
    $expiresAt: ISO8601DateTime
  ) {
    issueUserPromoCode(
      input: { email: $email, creditAmount: $creditAmount, code: $code, expiresAt: $expiresAt }
    ) {
      promoCode {
        code
      }
      errors
    }
  }
`;

const CREATE_GENERAL_PROMO_CODE = gql`
  mutation CreateGeneralPromoCode($usageLimit: Int!, $code: String, $expiresAt: ISO8601DateTime) {
    createGeneralPromoCode(input: { usageLimit: $usageLimit, code: $code, expiresAt: $expiresAt }) {
      promoCode {
        code
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

// Converts a datetime-local value ("2026-08-01T12:00") to ISO8601, or null when blank.
const toIso = (value: string) => (value ? new Date(value).toISOString() : null);

function ManagePromos() {
  const [currentPage, setCurrentPage] = useState(1);
  const perPage = 20;

  const { data, loading, error, refetch } = useQuery(ADMIN_PROMO_CODES_QUERY, {
    variables: { page: currentPage, perPage },
  });

  // Issue-to-user form state
  const [email, setEmail] = useState('');
  const [creditAmount, setCreditAmount] = useState('');
  const [userCode, setUserCode] = useState('');
  const [userExpiresAt, setUserExpiresAt] = useState('');

  // General code form state
  const [generalCode, setGeneralCode] = useState('');
  const [usageLimit, setUsageLimit] = useState('');
  const [generalExpiresAt, setGeneralExpiresAt] = useState('');

  const [issueUserPromoCode, { loading: issuing }] = useMutation(ISSUE_USER_PROMO_CODE);
  const [createGeneralPromoCode, { loading: creating }] = useMutation(CREATE_GENERAL_PROMO_CODE);

  const promoCodes: PromoCode[] = data?.adminPromoCodes.promoCodes || [];
  const totalCount = data?.adminPromoCodes.totalCount || 0;
  const totalPages = data?.adminPromoCodes.totalPages || 0;

  const handleIssueToUser = async (e: React.FormEvent) => {
    e.preventDefault();
    const amount = parseInt(creditAmount, 10);
    if (!email.trim() || !Number.isFinite(amount) || amount <= 0) {
      toast.error('Enter an email and a credit amount greater than 0');
      return;
    }

    const { data: result } = await issueUserPromoCode({
      variables: {
        email: email.trim(),
        creditAmount: amount,
        code: userCode.trim() || null,
        expiresAt: toIso(userExpiresAt),
      },
    });

    const payload = result.issueUserPromoCode;
    if (payload.errors.length === 0) {
      toast.success(`Issued code ${payload.promoCode.code} to ${email.trim()}`);
      setEmail('');
      setCreditAmount('');
      setUserCode('');
      setUserExpiresAt('');
      setCurrentPage(1);
      refetch();
    } else {
      toast.error(payload.errors.join(', '));
    }
  };

  const handleCreateGeneral = async (e: React.FormEvent) => {
    e.preventDefault();
    const limit = parseInt(usageLimit, 10);
    if (!Number.isFinite(limit) || limit <= 0) {
      toast.error('Enter a maximum number of redemptions greater than 0');
      return;
    }

    const { data: result } = await createGeneralPromoCode({
      variables: {
        usageLimit: limit,
        code: generalCode.trim() || null,
        expiresAt: toIso(generalExpiresAt),
      },
    });

    const payload = result.createGeneralPromoCode;
    if (payload.errors.length === 0) {
      toast.success(`Created code ${payload.promoCode.code}`);
      setGeneralCode('');
      setUsageLimit('');
      setGeneralExpiresAt('');
      setCurrentPage(1);
      refetch();
    } else {
      toast.error(payload.errors.join(', '));
    }
  };

  return (
    <div className="flex flex-col space-y-6">
      <Toaster />
      <div className="flex flex-col sm:flex-row sm:justify-between sm:items-center gap-4">
        <h2 className="text-2xl font-bold text-black">Credits &amp; Promos</h2>
        <div className="text-sm text-gray-600">
          Total Codes: <span className="font-semibold">{totalCount}</span>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Issue to a specific user */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <UserPlus className="h-5 w-5" />
              Issue to a user
            </CardTitle>
            <CardDescription>
              Assign a code to one existing user for the credits you specify. Only that user can
              redeem it, once.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleIssueToUser} className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="user-email">User email</Label>
                <Input
                  id="user-email"
                  type="email"
                  placeholder="user@example.com"
                  value={email}
                  onChange={e => setEmail(e.target.value)}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="credit-amount">Credit amount</Label>
                <Input
                  id="credit-amount"
                  type="number"
                  min="1"
                  placeholder="25"
                  value={creditAmount}
                  onChange={e => setCreditAmount(e.target.value)}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="user-code">Code (optional)</Label>
                <Input
                  id="user-code"
                  placeholder="Leave blank to auto-generate"
                  value={userCode}
                  onChange={e => setUserCode(e.target.value)}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="user-expires">Expires (optional)</Label>
                <Input
                  id="user-expires"
                  type="datetime-local"
                  value={userExpiresAt}
                  onChange={e => setUserExpiresAt(e.target.value)}
                />
              </div>
              <Button type="submit" disabled={issuing} className="w-full">
                {issuing ? 'Issuing…' : 'Issue code'}
              </Button>
            </form>
          </CardContent>
        </Card>

        {/* General code */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Gift className="h-5 w-5" />
              Create a general code
            </CardTitle>
            <CardDescription>
              A code any user can redeem once, for 1 credit each, up to the total limit you set.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleCreateGeneral} className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="general-code">Code (optional)</Label>
                <Input
                  id="general-code"
                  placeholder="Leave blank to auto-generate"
                  value={generalCode}
                  onChange={e => setGeneralCode(e.target.value)}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="usage-limit">Max total redemptions</Label>
                <Input
                  id="usage-limit"
                  type="number"
                  min="1"
                  placeholder="1000"
                  value={usageLimit}
                  onChange={e => setUsageLimit(e.target.value)}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="general-expires">Expires (optional)</Label>
                <Input
                  id="general-expires"
                  type="datetime-local"
                  value={generalExpiresAt}
                  onChange={e => setGeneralExpiresAt(e.target.value)}
                />
              </div>
              <div className="rounded-md bg-gray-50 px-3 py-2 text-sm text-gray-600">
                Grants <span className="font-semibold">1 credit</span> per redemption.
              </div>
              <Button type="submit" disabled={creating} className="w-full">
                {creating ? 'Creating…' : 'Create code'}
              </Button>
            </form>
          </CardContent>
        </Card>
      </div>

      {error && (
        <div className="text-red-500 text-sm bg-red-50 p-3 rounded-md">Error: {error.message}</div>
      )}

      <Card>
        {loading ? (
          <div className="p-6 space-y-3">
            <Skeleton className="h-10 w-full" />
            <Skeleton className="h-10 w-full" />
            <Skeleton className="h-10 w-full" />
          </div>
        ) : promoCodes.length === 0 ? (
          <div className="flex justify-center items-center h-48">
            <p className="text-gray-500 text-lg">No promo codes yet</p>
          </div>
        ) : (
          <>
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Code</TableHead>
                    <TableHead className="text-center">Credits</TableHead>
                    <TableHead>Assigned to</TableHead>
                    <TableHead className="text-center">Redeemed</TableHead>
                    <TableHead>Expires</TableHead>
                    <TableHead>Created</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {promoCodes.map(promo => (
                    <TableRow key={promo.id}>
                      <TableCell className="font-mono font-medium">{promo.code}</TableCell>
                      <TableCell className="text-center">{promo.creditAmount}</TableCell>
                      <TableCell className="text-gray-600">
                        {promo.user ? promo.user.email : <span className="italic">General</span>}
                      </TableCell>
                      <TableCell className="text-center">
                        {promo.timesRedeemed ?? 0}
                        {promo.usageLimit != null ? ` / ${promo.usageLimit}` : ''}
                      </TableCell>
                      <TableCell className="text-gray-600 text-sm">
                        {promo.expiresAt ? formatDate(promo.expiresAt) : '—'}
                      </TableCell>
                      <TableCell className="text-gray-600 text-sm">
                        {formatDate(promo.createdAt)}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>

            {totalPages > 1 && (
              <div className="flex items-center justify-between border-t px-4 py-3">
                <div className="text-sm text-gray-600">
                  Page {currentPage} of {totalPages}
                </div>
                <div className="flex gap-2">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                    disabled={currentPage === 1 || loading}
                  >
                    <ChevronLeft className="h-4 w-4" />
                    Previous
                  </Button>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
                    disabled={currentPage === totalPages || loading}
                  >
                    Next
                    <ChevronRight className="h-4 w-4" />
                  </Button>
                </div>
              </div>
            )}
          </>
        )}
      </Card>
    </div>
  );
}

export default withAuth(ManagePromos);
