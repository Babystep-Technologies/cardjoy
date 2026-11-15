/**
 * Ties an invitation to a registry (#250): the host picks one of their registries, or starts a new
 * one for this event, and guests get a link to it from the invitation. Saves as soon as the choice
 * changes, through its own mutation, so it doesn't depend on the invitation form's save.
 */
import React from 'react';
import { gql, useMutation, useQuery } from '@apollo/client';
import { Link } from 'react-router-dom';
import { toast } from 'sonner';
import { Gift } from 'lucide-react';
import { Button } from '@/components/ui/button';
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
    }
  }
`;

export const SET_INVITATION_REGISTRY = gql`
  mutation SetInvitationRegistry($input: SetInvitationRegistryInput!) {
    setInvitationRegistry(input: $input) {
      invitation {
        id
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
  /** Prefill for a registry started from here: named after the event, on its date. */
  title?: string;
  eventDate?: string;
}

const InvitationRegistryLink: React.FC<Props> = ({
  invitationExternalId,
  registryExternalId,
  title,
  eventDate,
}) => {
  const { data } = useQuery(GET_MY_REGISTRIES);
  const [setRegistry, { loading }] = useMutation(SET_INVITATION_REGISTRY);

  const registries: { externalId: string; title: string }[] = data?.myRegistries ?? [];

  const newRegistryParams = new URLSearchParams({ forInvitation: invitationExternalId });
  if (title) newRegistryParams.set('title', title);
  if (eventDate) newRegistryParams.set('eventDate', eventDate);

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
        <CardTitle className="flex items-center gap-2">
          <Gift className="h-5 w-5 text-pink-500" />
          Registry
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        {registries.length > 0 && (
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
        )}
        <div className="flex flex-wrap items-center gap-2">
          <Button asChild variant="outline" className="border-2">
            <Link to={`/registry/new?${newRegistryParams.toString()}`}>
              {registries.length > 0 ? 'Create a new registry for this event' : 'Create a registry'}
            </Link>
          </Button>
          {registryExternalId && (
            <Button asChild variant="ghost">
              <Link to={`/registry/${registryExternalId}/edit`}>Edit linked registry</Link>
            </Button>
          )}
        </div>
        <p className="text-xs text-gray-500">
          Guests who open the invitation get a link to the registry, where they can claim gifts. It
          only shows while the registry is shared.
        </p>
      </CardContent>
    </Card>
  );
};

export default InvitationRegistryLink;
