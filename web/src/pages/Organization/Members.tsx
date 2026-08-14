import { useState } from 'react';
import { gql, useMutation, useQuery } from '@apollo/client';
import { Link } from 'react-router-dom';
import { Building2, LoaderCircle, Mail, Trash2, UserPlus } from 'lucide-react';
import { Toaster, toast } from 'sonner';
import withAuth from '@/lib/with-auth';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Label } from '@/components/ui/label';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Textarea } from '@/components/ui/textarea';
import { useOrganization, VIEWER } from '@/contexts/OrganizationContext';

/**
 * Who is in the organization the user is currently acting in, who has been asked, and — for an
 * admin — the controls to change both.
 *
 * Every action here is admin-gated on the server; a member gets the same roster read-only, because
 * seeing your colleagues is not the same as being able to remove them.
 *
 * The one rule this page deliberately does *not* enforce is "an organization must keep at least one
 * admin". That guard lives on OrganizationMembership, and hiding the button locally would mean two
 * implementations of it that can drift. The buttons stay live and the server's error is rendered.
 */

const ORGANIZATION_MEMBERS = gql`
  query OrganizationMembers {
    viewer {
      id
      email
      activeOrganization {
        id
        name
        memberships {
          id
          role
          createdAt
          user {
            id
            name
            email
          }
        }
        pendingInvitations {
          id
          email
          role
          createdAt
          expiresAt
          invitedBy {
            id
            name
          }
        }
      }
    }
  }
`;

const INVITE_TO_ORGANIZATION = gql`
  mutation InviteToOrganization($input: InviteToOrganizationInput!) {
    inviteToOrganization(input: $input) {
      invitations {
        id
        email
      }
      skippedEmails
      errors
    }
  }
`;

const REVOKE_ORGANIZATION_INVITATION = gql`
  mutation RevokeOrganizationInvitation($input: RevokeOrganizationInvitationInput!) {
    revokeOrganizationInvitation(input: $input) {
      invitation {
        id
      }
      errors
    }
  }
`;

const UPDATE_ORGANIZATION_MEMBERSHIP = gql`
  mutation UpdateOrganizationMembership($input: UpdateOrganizationMembershipInput!) {
    updateOrganizationMembership(input: $input) {
      membership {
        id
        role
      }
      errors
    }
  }
`;

const REMOVE_ORGANIZATION_MEMBER = gql`
  mutation RemoveOrganizationMember($input: RemoveOrganizationMemberInput!) {
    removeOrganizationMember(input: $input) {
      success
      errors
    }
  }
`;

type Membership = {
  id: string;
  role: string;
  createdAt: string;
  user: { id: string; name: string; email: string };
};

type PendingInvitation = {
  id: string;
  email: string;
  role: string;
  createdAt: string;
  expiresAt: string;
  invitedBy: { id: string; name: string } | null;
};

type MembersData = {
  viewer: {
    id: string;
    email: string;
    activeOrganization: {
      id: string;
      name: string;
      memberships: Membership[];
      pendingInvitations: PendingInvitation[];
    } | null;
  } | null;
};

const formatDate = (iso: string) =>
  new Date(iso).toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' });

/**
 * Addresses out of whatever an admin pasted in. Splitting on commas, semicolons, and whitespace
 * covers a hand-typed list and a block copied out of a mail client alike; the server does the
 * validating, deduping, and skipping of people who are already in.
 */
const parseEmails = (raw: string): string[] =>
  raw
    .split(/[\s,;]+/)
    .map(email => email.trim())
    .filter(Boolean);

const errorList = (errors: string[]) =>
  errors.length > 0 && (
    <ul className="space-y-1 text-sm font-medium text-red-600">
      {errors.map(error => (
        <li key={error}>{error}</li>
      ))}
    </ul>
  );

const OrganizationMembersPage: React.FC = () => {
  const { activeOrganization, loading: organizationLoading } = useOrganization();
  const isAdmin = activeOrganization?.role === 'admin';

  const { data, loading, refetch } = useQuery<MembersData>(ORGANIZATION_MEMBERS, {
    fetchPolicy: 'cache-and-network',
    skip: !activeOrganization,
  });

  const organization = data?.viewer?.activeOrganization ?? null;
  const viewerId = data?.viewer?.id ?? null;
  const memberships = organization?.memberships ?? [];
  const pendingInvitations = organization?.pendingInvitations ?? [];

  const [inviteToOrganization] = useMutation(INVITE_TO_ORGANIZATION);
  const [revokeInvitation] = useMutation(REVOKE_ORGANIZATION_INVITATION);
  // An admin can act on their own row — that is how the last admin discovers they can't. Both of
  // these can therefore change the caller's own standing, which the header switcher reads from
  // `Viewer`, so that query is refreshed alongside the roster.
  const refreshesViewer = { refetchQueries: [{ query: VIEWER }], awaitRefetchQueries: true };
  const [updateMembership] = useMutation(UPDATE_ORGANIZATION_MEMBERSHIP, refreshesViewer);
  const [removeMember] = useMutation(REMOVE_ORGANIZATION_MEMBER, refreshesViewer);

  const [emailsInput, setEmailsInput] = useState('');
  const [inviteRole, setInviteRole] = useState('member');
  const [inviting, setInviting] = useState(false);
  const [inviteErrors, setInviteErrors] = useState<string[]>([]);

  const [rosterErrors, setRosterErrors] = useState<string[]>([]);
  const [busyMembershipId, setBusyMembershipId] = useState<string | null>(null);
  const [busyInvitationId, setBusyInvitationId] = useState<string | null>(null);
  // Removing someone is the one irreversible action here, so it takes a second click. Kept as an id
  // rather than a modal: the confirmation belongs on the row you are about to act on.
  const [confirmingRemovalId, setConfirmingRemovalId] = useState<string | null>(null);

  const emails = parseEmails(emailsInput);

  const handleInvite = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!organization) return;

    setInviteErrors([]);
    setInviting(true);

    try {
      const { data: result } = await inviteToOrganization({
        variables: { input: { organizationId: organization.id, emails, role: inviteRole } },
      });
      const payload = result?.inviteToOrganization;
      const errors: string[] = payload?.errors ?? [];

      if (errors.length > 0) {
        setInviteErrors(errors);
        return;
      }

      const sent: { id: string; email: string }[] = payload?.invitations ?? [];
      const skipped: string[] = payload?.skippedEmails ?? [];

      // A batch is not all-or-nothing on the server, so say what actually happened to it rather
      // than claiming every address was invited.
      if (sent.length > 0) {
        toast.success(sent.length === 1 ? `Invited ${sent[0].email}.` : `Invited ${sent.length}.`);
      }
      if (skipped.length > 0) {
        toast.info(`Already invited or a member: ${skipped.join(', ')}`);
      }

      setEmailsInput('');
      await refetch();
    } catch (error) {
      setInviteErrors([error instanceof Error ? error.message : 'Could not send the invitations.']);
    } finally {
      setInviting(false);
    }
  };

  const handleRevoke = async (invitation: PendingInvitation) => {
    setRosterErrors([]);
    setBusyInvitationId(invitation.id);

    try {
      const { data: result } = await revokeInvitation({
        variables: { input: { id: invitation.id } },
      });
      const errors: string[] = result?.revokeOrganizationInvitation?.errors ?? [];

      if (errors.length > 0) {
        setRosterErrors(errors);
        return;
      }

      await refetch();
      toast.success(`Revoked the invitation to ${invitation.email}.`);
    } catch (error) {
      setRosterErrors([
        error instanceof Error ? error.message : 'Could not revoke the invitation.',
      ]);
    } finally {
      setBusyInvitationId(null);
    }
  };

  const handleRoleChange = async (membership: Membership, role: string) => {
    setRosterErrors([]);
    setBusyMembershipId(membership.id);

    try {
      const { data: result } = await updateMembership({
        variables: { input: { id: membership.id, role } },
      });
      const errors: string[] = result?.updateOrganizationMembership?.errors ?? [];

      if (errors.length > 0) {
        setRosterErrors(errors);
        return;
      }

      await refetch();
      toast.success(
        role === 'admin'
          ? `${membership.user.name} is now an admin.`
          : `${membership.user.name} is now a member.`
      );
    } catch (error) {
      setRosterErrors([error instanceof Error ? error.message : 'Could not change the role.']);
    } finally {
      setBusyMembershipId(null);
    }
  };

  const handleRemove = async (membership: Membership) => {
    setRosterErrors([]);
    setBusyMembershipId(membership.id);

    try {
      const { data: result } = await removeMember({
        variables: { input: { id: membership.id } },
      });
      const errors: string[] = result?.removeOrganizationMember?.errors ?? [];

      if (errors.length > 0) {
        setRosterErrors(errors);
        return;
      }

      setConfirmingRemovalId(null);
      await refetch();
      toast.success(`Removed ${membership.user.name}.`);
    } catch (error) {
      setRosterErrors([error instanceof Error ? error.message : 'Could not remove the member.']);
    } finally {
      setBusyMembershipId(null);
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
          You're working in your personal context. Switch to an organization from the header to see
          its members.
        </p>
        <Button asChild className="mt-6">
          <Link to="/organizations/new">Create an organization</Link>
        </Button>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-5xl px-4 pt-12 pb-16">
      <Toaster />

      <header className="space-y-2">
        <h1 className="text-3xl font-bold text-black">Members</h1>
        <p className="text-gray-600">
          Everyone in {activeOrganization.name}, and the invitations still waiting on a reply.
        </p>
        {!isAdmin && (
          <p className="rounded-md bg-gray-50 px-3 py-2 text-sm text-gray-600">
            You're a member of this organization, so this roster is read-only. Ask an admin to
            invite or remove people.
          </p>
        )}
      </header>

      {loading && !organization ? (
        <div className="flex justify-center py-16">
          <LoaderCircle className="h-6 w-6 animate-spin text-gray-400" />
        </div>
      ) : (
        <div className="mt-8 space-y-8">
          {isAdmin && (
            <Card>
              <CardHeader>
                <CardTitle>Invite people</CardTitle>
                <CardDescription>
                  They'll get a join link by email. Anyone without a CardJoy account can sign up and
                  still land here.
                </CardDescription>
              </CardHeader>
              <CardContent>
                <form onSubmit={handleInvite} className="max-w-xl space-y-5">
                  <div className="space-y-2">
                    <Label htmlFor="invite-emails">Email addresses</Label>
                    <Textarea
                      id="invite-emails"
                      value={emailsInput}
                      onChange={e => setEmailsInput(e.target.value)}
                      placeholder="ada@example.com, grace@example.com"
                      rows={3}
                    />
                    <p className="text-xs text-gray-500">
                      Separate addresses with commas, spaces, or new lines. People who are already
                      invited or already here are skipped.
                    </p>
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor="invite-role">Role</Label>
                    <Select value={inviteRole} onValueChange={setInviteRole}>
                      <SelectTrigger id="invite-role" className="w-full sm:w-56">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="member">Member</SelectItem>
                        <SelectItem value="admin">Admin</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>

                  {errorList(inviteErrors)}

                  <Button type="submit" disabled={inviting || emails.length === 0}>
                    {inviting ? (
                      <LoaderCircle className="h-4 w-4 animate-spin" />
                    ) : (
                      <UserPlus className="h-4 w-4" />
                    )}
                    {inviting
                      ? 'Sending...'
                      : emails.length > 1
                        ? `Send ${emails.length} invitations`
                        : 'Send invitation'}
                  </Button>
                </form>
              </CardContent>
            </Card>
          )}

          {isAdmin && (
            <Card>
              <CardHeader>
                <CardTitle>Pending invitations</CardTitle>
                <CardDescription>
                  Sent but not yet accepted. Revoking one stops its link working immediately.
                </CardDescription>
              </CardHeader>
              <CardContent>
                {pendingInvitations.length === 0 ? (
                  <p className="text-sm text-gray-500">No invitations are waiting on a reply.</p>
                ) : (
                  <ul className="divide-y divide-gray-100">
                    {pendingInvitations.map(invitation => (
                      <li
                        key={invitation.id}
                        className="flex flex-wrap items-center gap-3 py-3 first:pt-0 last:pb-0"
                      >
                        <Mail className="h-4 w-4 shrink-0 text-gray-400" />
                        <div className="min-w-0 flex-1">
                          <p className="truncate font-medium text-gray-900">{invitation.email}</p>
                          <p className="text-xs text-gray-500">
                            Invited by {invitation.invitedBy?.name ?? 'an admin'} on{' '}
                            {formatDate(invitation.createdAt)} • expires{' '}
                            {formatDate(invitation.expiresAt)}
                          </p>
                        </div>
                        <Badge variant="outline" className="capitalize">
                          {invitation.role}
                        </Badge>
                        <Button
                          type="button"
                          variant="ghost"
                          disabled={busyInvitationId === invitation.id}
                          onClick={() => handleRevoke(invitation)}
                        >
                          {busyInvitationId === invitation.id && (
                            <LoaderCircle className="h-4 w-4 animate-spin" />
                          )}
                          Revoke
                        </Button>
                      </li>
                    ))}
                  </ul>
                )}
              </CardContent>
            </Card>
          )}

          <Card>
            <CardHeader>
              <CardTitle>Roster</CardTitle>
              <CardDescription>
                {memberships.length === 1
                  ? "You're the only person here so far."
                  : `${memberships.length} people share this organization's credits, cards, and branding.`}
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <ul className="divide-y divide-gray-100">
                {memberships.map(membership => {
                  const isSelf = membership.user.id === viewerId;
                  const busy = busyMembershipId === membership.id;

                  return (
                    <li
                      key={membership.id}
                      className="flex flex-wrap items-center gap-3 py-3 first:pt-0 last:pb-0"
                    >
                      <div className="min-w-0 flex-1">
                        <p className="flex items-center gap-2 font-medium text-gray-900">
                          <span className="truncate">{membership.user.name}</span>
                          {isSelf && (
                            <Badge variant="secondary" className="shrink-0">
                              You
                            </Badge>
                          )}
                        </p>
                        <p className="truncate text-sm text-gray-600">{membership.user.email}</p>
                        <p className="text-xs text-gray-500">
                          Joined {formatDate(membership.createdAt)}
                        </p>
                      </div>

                      {isAdmin ? (
                        <Select
                          value={membership.role}
                          disabled={busy}
                          onValueChange={role => {
                            if (role !== membership.role) handleRoleChange(membership, role);
                          }}
                        >
                          <SelectTrigger
                            className="w-32"
                            aria-label={`Role for ${membership.user.name}`}
                          >
                            <SelectValue />
                          </SelectTrigger>
                          <SelectContent>
                            <SelectItem value="member">Member</SelectItem>
                            <SelectItem value="admin">Admin</SelectItem>
                          </SelectContent>
                        </Select>
                      ) : (
                        <Badge variant="outline" className="capitalize">
                          {membership.role}
                        </Badge>
                      )}

                      {isAdmin &&
                        (confirmingRemovalId === membership.id ? (
                          <span className="flex items-center gap-1">
                            <Button
                              type="button"
                              variant="destructive"
                              disabled={busy}
                              onClick={() => handleRemove(membership)}
                            >
                              {busy && <LoaderCircle className="h-4 w-4 animate-spin" />}
                              {isSelf ? 'Remove me' : 'Confirm'}
                            </Button>
                            <Button
                              type="button"
                              variant="ghost"
                              onClick={() => setConfirmingRemovalId(null)}
                            >
                              Cancel
                            </Button>
                          </span>
                        ) : (
                          <Button
                            type="button"
                            variant="ghost"
                            disabled={busy}
                            aria-label={`Remove ${membership.user.name}`}
                            onClick={() => {
                              setRosterErrors([]);
                              setConfirmingRemovalId(membership.id);
                            }}
                          >
                            <Trash2 className="h-4 w-4" />
                          </Button>
                        ))}
                    </li>
                  );
                })}
              </ul>

              {errorList(rosterErrors)}
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  );
};

export default withAuth(OrganizationMembersPage);
