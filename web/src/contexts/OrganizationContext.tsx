import { createContext, useCallback, useContext, useMemo, useState } from 'react';
import { gql, useApolloClient, useMutation, useQuery } from '@apollo/client';
import { useAuth } from '@/contexts/AuthContext';

/**
 * Which organization the signed-in user is acting in.
 *
 * This can't come from the JWT the way `AuthContext` gets name/email: the token lives six months
 * and the active organization changes whenever the user switches, so it has to be read from the
 * server on every load. `viewer` is that read.
 */

export const VIEWER = gql`
  query Viewer {
    viewer {
      id
      activeOrganization {
        id
        name
        slug
      }
      organizationMemberships {
        id
        role
        organization {
          id
          name
          slug
        }
      }
    }
  }
`;

const SWITCH_ORGANIZATION = gql`
  mutation SwitchOrganization($input: SwitchOrganizationInput!) {
    switchOrganization(input: $input) {
      user {
        id
        activeOrganization {
          id
          name
          slug
        }
      }
      errors
    }
  }
`;

export type OrganizationSummary = {
  id: string;
  name: string;
  slug: string;
  /** The signed-in user's role in this organization — 'admin' or 'member'. */
  role: string;
};

type ViewerOrganization = { id: string; name: string; slug: string };

type ViewerData = {
  viewer: {
    id: string;
    activeOrganization: ViewerOrganization | null;
    organizationMemberships: {
      id: string;
      role: string;
      organization: ViewerOrganization | null;
    }[];
  } | null;
};

interface OrganizationContextType {
  /** The organization the user is acting in; null means Personal, which is a real context. */
  activeOrganization: OrganizationSummary | null;
  /** Every organization the user belongs to, Personal excluded. */
  organizations: OrganizationSummary[];
  /** Move into an organization, or back to Personal by passing null. */
  switchOrganization: (organizationId: string | null) => Promise<void>;
  switching: boolean;
  /** Set when the last switch failed, so the switcher can say so instead of silently doing nothing. */
  switchError: string | null;
  loading: boolean;
}

const OrganizationContext = createContext<OrganizationContextType | undefined>(undefined);

export const OrganizationProvider = ({ children }: { children: React.ReactNode }) => {
  const { user, loading: authLoading } = useAuth();
  const client = useApolloClient();
  const [switching, setSwitching] = useState(false);
  const [switchError, setSwitchError] = useState<string | null>(null);

  const { data, loading } = useQuery<ViewerData>(VIEWER, { skip: !user });
  const [switchOrganizationMutation] = useMutation(SWITCH_ORGANIZATION);

  const organizations = useMemo<OrganizationSummary[]>(() => {
    const memberships = data?.viewer?.organizationMemberships ?? [];

    return memberships.flatMap(membership =>
      membership.organization ? [{ ...membership.organization, role: membership.role }] : []
    );
  }, [data]);

  const activeOrganization = useMemo<OrganizationSummary | null>(() => {
    const active = data?.viewer?.activeOrganization;
    if (!active) return null;

    // The role lives on the membership, not on the organization itself.
    const role =
      organizations.find(organization => organization.id === active.id)?.role ?? 'member';
    return { ...active, role };
  }, [data, organizations]);

  const switchOrganization = useCallback(
    async (organizationId: string | null) => {
      setSwitching(true);
      setSwitchError(null);

      try {
        const { data: result } = await switchOrganizationMutation({
          variables: { input: { organizationId } },
        });
        const errors: string[] = result?.switchOrganization?.errors ?? [];

        if (errors.length > 0) {
          setSwitchError(errors.join(', '));
          return;
        }

        // Everything the user sees is scoped to the active organization, so every cached result
        // from the previous context is now wrong. Without this you switch to another organization
        // and keep looking at your personal cards.
        await client.resetStore();
      } catch (error) {
        console.error('Failed to switch organization', error);
        setSwitchError('Could not switch — please try again.');
      } finally {
        setSwitching(false);
      }
    },
    [client, switchOrganizationMutation]
  );

  const value = useMemo<OrganizationContextType>(
    () => ({
      activeOrganization,
      organizations,
      switchOrganization,
      switching,
      switchError,
      // A signed-out visitor has no organization to resolve, so they are never "loading".
      loading: user ? authLoading || loading : false,
    }),
    [
      activeOrganization,
      organizations,
      switchOrganization,
      switching,
      switchError,
      user,
      authLoading,
      loading,
    ]
  );

  return <OrganizationContext.Provider value={value}>{children}</OrganizationContext.Provider>;
};

export const useOrganization = () => {
  const context = useContext(OrganizationContext);
  if (!context) {
    throw new Error('useOrganization must be used within an OrganizationProvider');
  }
  return context;
};
