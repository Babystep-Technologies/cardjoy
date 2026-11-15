/**
 * What the host sees first when they open their own invitation (#321): who is coming, a way to
 * remind them, the guest list, and Edit. The guest-facing page is one click away ("View as guest").
 * The guest list is only returned to the host by the API, so this is also the only place it loads.
 */
import React from 'react';
import { gql, useQuery } from '@apollo/client';
import { Link } from 'react-router-dom';
import { toast } from 'sonner';
import { ArrowLeft, Calendar, Copy, Eye, MapPin, Settings } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import RSVPManagement from './RSVPManagement';
import RemindGuests from './RemindGuests';
import InvitationRegistryLink from './InvitationRegistryLink';

const GET_HOST_VIEW = gql`
  query GetInvitationHostView($externalId: String!) {
    invitation(externalId: $externalId) {
      id
      externalId
      nextReminderAt
      rsvps {
        id
        guestName
        guestEmail
        status
        plusOne
        additionalGuestsCount
        plusOneName
        message
        createdAt
      }
      rsvpCounts {
        going
        maybe
        notGoing
        total
        totalAttendees
      }
      registry {
        externalId
        title
      }
    }
  }
`;

interface Props {
  externalId: string;
  title: string;
  eventDate: string;
  eventTime: string;
  location?: string | null;
  onViewAsGuest: () => void;
}

const HostView: React.FC<Props> = ({
  externalId,
  title,
  eventDate,
  eventTime,
  location,
  onViewAsGuest,
}) => {
  const { data } = useQuery(GET_HOST_VIEW, {
    variables: { externalId },
    fetchPolicy: 'cache-and-network',
  });
  const host = data?.invitation;
  const counts = host?.rsvpCounts ?? {
    going: 0,
    maybe: 0,
    notGoing: 0,
    total: 0,
    totalAttendees: 0,
  };

  const when = new Date(`${eventDate}T${eventTime}`).toLocaleString([], {
    dateStyle: 'full',
    timeStyle: 'short',
  });

  const copyLink = async () => {
    try {
      await navigator.clipboard.writeText(`${window.location.origin}/invitation/${externalId}`);
      toast.success('Invitation link copied');
    } catch {
      toast.error('Could not copy the link');
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-yellow-50 via-pink-50 to-blue-50">
      <div className="mx-auto max-w-3xl px-4 py-8">
        <Link
          to="/"
          className="mb-4 inline-flex items-center gap-2 text-gray-600 hover:text-gray-900"
        >
          <ArrowLeft className="h-4 w-4" />
          Dashboard
        </Link>

        <Card className="space-y-4 border-2 bg-white/95 p-6 shadow-xl">
          <div>
            <p className="text-xs font-medium uppercase tracking-wide text-gray-500">
              You're the host
            </p>
            <h1 className="mt-1 text-3xl font-bold">{title}</h1>
            <div className="mt-3 space-y-1 text-sm text-gray-600">
              <div className="flex items-center gap-2">
                <Calendar className="h-4 w-4" />
                {when}
              </div>
              {location && (
                <div className="flex items-center gap-2">
                  <MapPin className="h-4 w-4" />
                  {location}
                </div>
              )}
            </div>
          </div>

          <div className="flex flex-wrap gap-2">
            <Link to={`/invitation/${externalId}/edit`}>
              <Button className="gap-2">
                <Settings className="h-4 w-4" />
                Edit invitation
              </Button>
            </Link>
            <Button variant="outline" className="gap-2" onClick={copyLink}>
              <Copy className="h-4 w-4" />
              Copy link
            </Button>
            <Button variant="outline" className="gap-2" onClick={onViewAsGuest}>
              <Eye className="h-4 w-4" />
              View as guest
            </Button>
          </div>
        </Card>

        {host && (
          <>
            <div className="mt-8">
              <RSVPManagement rsvps={host.rsvps} rsvpCounts={counts} invitationTitle={title} />
            </div>

            <RemindGuests
              invitationExternalId={externalId}
              eventDate={eventDate}
              going={counts.going}
              maybe={counts.maybe}
              nextReminderAt={host.nextReminderAt}
            />

            <InvitationRegistryLink
              invitationExternalId={externalId}
              registryExternalId={host.registry?.externalId}
            />
          </>
        )}
      </div>
    </div>
  );
};

export default HostView;
