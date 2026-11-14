/**
 * Lets an invitation's host point guests at one of their standalone registries (#250). Saves as
 * soon as the choice changes, through its own mutation, so it doesn't depend on the invitation
 * form's save. Renders nothing when the host has no registry to pick.
 */
import React from 'react';
import { gql, useMutation, useQuery } from '@apollo/client';
import { toast } from 'sonner';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';

const GET_MY_REGISTRIES = gql`
  query MyRegistries {
    myRegistries {
      externalId
      title
      standalone
    }
  }
`;

const SET_INVITATION_REGISTRY = gql`
  mutation SetInvitationRegistry($input: SetInvitationRegistryInput!) {
    setInvitationRegistry(input: $input) {
      invitation {
        externalId
        registry {
          externalId
          title
        }
      }
      errors
    }
  }
`;

interface Props {
  invitationExternalId: string;
  registryExternalId?: string | null;
}

const InvitationRegistryLink: React.FC<Props> = ({ invitationExternalId, registryExternalId }) => {
  const { data } = useQuery(GET_MY_REGISTRIES);
  const [setRegistry, { loading }] = useMutation(SET_INVITATION_REGISTRY);

  const registries: { externalId: string; title: string; standalone: boolean }[] = (
    data?.myRegistries ?? []
  ).filter((r: { standalone: boolean }) => r.standalone);
  if (registries.length === 0) return null;

  const change = async (value: string) => {
    try {
      const { data: result } = await setRegistry({
        variables: {
          input: {
            invitationExternalId,
            registryExternalId: value === 'none' ? '' : value,
          },
        },
      });
      const errors: string[] = result?.setInvitationRegistry?.errors ?? [];
      if (errors.length > 0) toast.error(errors.join(', '));
      else toast.success(value === 'none' ? 'Registry unlinked' : 'Registry linked');
    } catch (e) {
      console.error('Failed to link registry', e);
      toast.error('Failed to update the registry link.');
    }
  };

  return (
    <Card className="mt-8">
      <CardHeader>
        <CardTitle>Link a registry</CardTitle>
      </CardHeader>
      <CardContent className="space-y-2">
        <Select value={registryExternalId || 'none'} onValueChange={change} disabled={loading}>
          <SelectTrigger className="border-2" aria-label="Registry to link">
            <SelectValue placeholder="No registry" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="none">No registry</SelectItem>
            {registries.map(r => (
              <SelectItem key={r.externalId} value={r.externalId}>
                {r.title}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <p className="text-xs text-gray-500">
          Guests who open the invitation get a link to the registry. It only shows while the
          registry is shared.
        </p>
      </CardContent>
    </Card>
  );
};

export default InvitationRegistryLink;
