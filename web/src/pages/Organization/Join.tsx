import { useState } from 'react';
import { gql, useApolloClient, useMutation, useQuery } from '@apollo/client';
import { Link, useLocation, useNavigate, useSearchParams } from 'react-router-dom';
import { Building2, LoaderCircle, MailX } from 'lucide-react';
import * as motion from 'motion/react-client';
import { Button } from '@/components/ui/button';
import { APP_TOKEN_KEY } from '@/lib/constants';
import { useAuth } from '@/contexts/AuthContext';
import { useOrganization } from '@/contexts/OrganizationContext';

/**
 * The join-by-link landing page: `/organizations/join?token=…`.
 *
 * Deliberately **not** wrapped in `withAuth`. The person holding this link may not have a CardJoy
 * account at all, and bouncing them to sign-in before they know who invited them or to what is how
 * an invitation gets ignored. `organizationInvitationPreview` is on the API's public allowlist so
 * the page can introduce itself while signed out; accepting still requires authentication.
 *
 * The token lives in the query string for the whole flow. Sign-in and sign-up carry it back through
 * their `redirect` param (the convention `web/src/lib/with-auth.tsx` established), so a brand-new
 * user signs up and returns here with the invitation intact rather than re-entering anything.
 */

const ORGANIZATION_INVITATION_PREVIEW = gql`
  query OrganizationInvitationPreview($token: String!) {
    organizationInvitationPreview(token: $token) {
      organizationName
      invitedByName
      valid
      reason
    }
  }
`;

const ACCEPT_ORGANIZATION_INVITATION = gql`
  mutation AcceptOrganizationInvitation($input: AcceptOrganizationInvitationInput!) {
    acceptOrganizationInvitation(input: $input) {
      organization {
        id
        name
      }
      errors
    }
  }
`;

type PreviewData = {
  organizationInvitationPreview: {
    organizationName: string;
    invitedByName: string;
    valid: boolean;
    reason: string | null;
  } | null;
};

/**
 * The exact strings `OrganizationInvitation` returns, both as the preview's `reason` and in the
 * accept mutation's `errors`. Matched here so each dead end can say what to do next instead of
 * repeating the API's one-line diagnosis — keep in sync with
 * `api/app/models/organization_invitation.rb`.
 */
const EXPIRED = 'This invitation has expired';
const REVOKED = 'This invitation has been revoked';
const ALREADY_ACCEPTED = 'This invitation has already been accepted';
const WRONG_EMAIL = 'This invitation was sent to a different email address';

const Frame: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <div className="flex min-h-screen flex-col items-center justify-start px-4 pt-20 pb-12">
    <motion.div
      className="w-full max-w-md space-y-6 text-center"
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5 }}
    >
      {children}
    </motion.div>
  </div>
);

const Spinner: React.FC = () => (
  <div className="flex min-h-screen items-center justify-center">
    <LoaderCircle className="h-6 w-6 animate-spin text-gray-400" />
  </div>
);

const OrganizationJoin: React.FC = () => {
  const [searchParams] = useSearchParams();
  const location = useLocation();
  const navigate = useNavigate();
  const client = useApolloClient();
  const { user, setUser, loading: authLoading } = useAuth();
  const { switchOrganization } = useOrganization();

  const token = searchParams.get('token');

  // Never from the cache: a link is single-use, and an accepted or revoked invitation must not keep
  // rendering the Accept button because an earlier visit cached it as live.
  const { data, loading } = useQuery<PreviewData>(ORGANIZATION_INVITATION_PREVIEW, {
    variables: { token },
    skip: !token,
    fetchPolicy: 'network-only',
  });

  const [acceptInvitation] = useMutation(ACCEPT_ORGANIZATION_INVITATION);
  const [accepting, setAccepting] = useState(false);
  const [acceptError, setAcceptError] = useState<string | null>(null);

  const preview = data?.organizationInvitationPreview ?? null;

  // Round-trip target for sign-in and sign-up. The whole path, token included, so the invitation
  // survives an account being created in the middle of the flow.
  const joinHref = `${location.pathname}${location.search}`;
  const signInHref = `/sign_in?redirect=${encodeURIComponent(joinHref)}`;
  const signUpHref = `/sign_up?redirect=${encodeURIComponent(joinHref)}`;

  const handleAccept = async () => {
    setAcceptError(null);
    setAccepting(true);

    try {
      const { data: result } = await acceptInvitation({ variables: { input: { token } } });
      const payload = result?.acceptOrganizationInvitation;
      const errors: string[] = payload?.errors ?? [];

      if (errors.length > 0 || !payload?.organization) {
        setAcceptError(errors[0] ?? 'Could not accept the invitation.');
        return;
      }

      // Land them inside the organization they just joined rather than in Personal, wondering what
      // the link did. `switchOrganization` resets the store, so the dashboard reads it fresh.
      await switchOrganization(payload.organization.id);
      navigate('/dashboard');
    } catch (error) {
      setAcceptError(
        error instanceof Error
          ? error.message
          : 'Could not accept the invitation. Please try again.'
      );
    } finally {
      setAccepting(false);
    }
  };

  // Signing out here has to preserve the join link, which `AuthContext.logout` can't do — it hard
  // navigates to a bare /sign_in and the token is gone.
  const handleSwitchAccounts = async () => {
    localStorage.removeItem(APP_TOKEN_KEY);
    setUser(null);
    await client.clearStore();
    navigate(signInHref);
  };

  const deadEnd = (title: string, body: React.ReactNode) => (
    <Frame>
      <MailX className="mx-auto h-10 w-10 text-gray-400" />
      <div className="space-y-2">
        <h1 className="text-2xl font-bold text-black">{title}</h1>
        <div className="space-y-3 text-gray-600">{body}</div>
      </div>
    </Frame>
  );

  if (!token) {
    return deadEnd(
      'This link is incomplete',
      <p>
        The invitation token is missing from the address. Open the link from your invitation email
        again, or ask whoever invited you to resend it.
      </p>
    );
  }

  if (loading || authLoading) return <Spinner />;

  // Null covers a token that matches nothing and an organization that has since been archived. Both
  // read the same way to the visitor, and telling them apart would make this a probe for live
  // tokens.
  if (!preview) {
    return deadEnd(
      "We couldn't find that invitation",
      <p>
        This link doesn't match an invitation. It may have been mistyped, or the organization may no
        longer exist. Ask whoever invited you for a fresh link.
      </p>
    );
  }

  const { organizationName, invitedByName, reason } = preview;

  if (!preview.valid) {
    if (reason === ALREADY_ACCEPTED) {
      return deadEnd(
        'This invitation has already been used',
        <>
          <p>
            If that was you, you're already a member of {organizationName} — switch to it from the
            menu in the header.
          </p>
          <Button asChild>
            <Link to={user ? '/dashboard' : signInHref}>
              {user ? 'Go to your dashboard' : 'Sign in'}
            </Link>
          </Button>
        </>
      );
    }

    if (reason === REVOKED) {
      return deadEnd(
        'This invitation was withdrawn',
        <p>
          {invitedByName} revoked the invitation to {organizationName}, so this link no longer
          works. Ask them to send a new one if you still need access.
        </p>
      );
    }

    if (reason === EXPIRED) {
      return deadEnd(
        'This invitation has expired',
        <p>
          Join links to {organizationName} are good for two weeks, and this one has passed that. Ask{' '}
          {invitedByName} to invite you again.
        </p>
      );
    }

    return deadEnd(
      'This invitation is no longer usable',
      <p>
        {reason ?? `The link to ${organizationName} no longer works.`} Ask {invitedByName} to send a
        new one.
      </p>
    );
  }

  return (
    <Frame>
      <Building2 className="mx-auto h-10 w-10 text-gray-900" />

      <div className="space-y-2">
        <h1 className="text-3xl font-bold text-black">Join {organizationName}</h1>
        <p className="text-gray-600">
          {invitedByName} invited you to join {organizationName} on CardJoy — sharing its credits,
          cards, and branding with the rest of the team.
        </p>
      </div>

      {acceptError === WRONG_EMAIL ? (
        // The confusing one if left as a bare error: the link works, the person is signed in, and
        // nothing they do on this page will help until they change accounts.
        <div className="space-y-3">
          <p className="text-sm font-medium text-red-600">
            This invitation was sent to a different email address. You're signed in as {user?.email}
            .
          </p>
          <div className="flex flex-col gap-2 sm:flex-row sm:justify-center">
            <Button type="button" onClick={handleSwitchAccounts}>
              Sign out and switch accounts
            </Button>
            <Button asChild variant="ghost">
              <Link to="/dashboard">Stay signed in</Link>
            </Button>
          </div>
        </div>
      ) : user ? (
        <div className="space-y-3">
          <Button type="button" onClick={handleAccept} disabled={accepting}>
            {accepting && <LoaderCircle className="h-4 w-4 animate-spin" />}
            {accepting ? 'Joining...' : `Join ${organizationName}`}
          </Button>
          <p className="text-xs text-gray-500">You're signed in as {user.email}.</p>
          {acceptError && <p className="text-sm font-medium text-red-600">{acceptError}</p>}
        </div>
      ) : (
        <div className="space-y-3">
          <div className="flex flex-col gap-2 sm:flex-row sm:justify-center">
            <Button asChild>
              <Link to={signUpHref}>Create an account</Link>
            </Button>
            <Button asChild variant="outline">
              <Link to={signInHref}>Sign in</Link>
            </Button>
          </div>
          <p className="text-xs text-gray-500">
            We'll bring you straight back here to finish joining.
          </p>
        </div>
      )}
    </Frame>
  );
};

export default OrganizationJoin;
