import { useParams, useNavigate } from 'react-router-dom';
import { gql, useQuery } from '@apollo/client';
import LoadingScreen from '@/components/Loading';
import ErrorScreen from '@/components/Error';
import { Rsvp } from '@/types/app';
import { Toaster } from 'sonner';
import { Button } from '@/components/ui/button';
import { ArrowLeft } from 'lucide-react';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import clsx from 'clsx';

const GET_INVITATION_FOR_ADMIN = gql`
  query GetInvitationForAdmin($externalId: String!) {
    invitation(externalId: $externalId) {
      id
      externalId
      title
      description
      location
      eventDate
      eventTime
      eventTimezone
      attire
      customInstructions
      coverImageUrl
      createdAt
      user {
        id
        name
        email
      }
      rsvpCounts {
        going
        maybe
        notGoing
        total
        totalAttendees
      }
      rsvps {
        id
        guestName
        guestEmail
        status
        additionalGuestsCount
        plusOneName
        message
        createdAt
        user {
          id
          name
          email
        }
      }
    }
  }
`;

const getStatusBadgeClass = (status: string) => {
  switch (status) {
    case 'going':
      return 'bg-green-100 text-green-800';
    case 'maybe':
      return 'bg-yellow-100 text-yellow-800';
    case 'not_going':
      return 'bg-gray-100 text-gray-700';
    default:
      return 'bg-gray-100 text-gray-700';
  }
};

const formatStatus = (status: string) => {
  switch (status) {
    case 'going':
      return 'Going';
    case 'maybe':
      return 'Maybe';
    case 'not_going':
      return 'Not Going';
    default:
      return status;
  }
};

export default function AdminInvitation() {
  const { externalId } = useParams();
  const navigate = useNavigate();

  const { data, loading, error } = useQuery(GET_INVITATION_FOR_ADMIN, {
    variables: { externalId },
    fetchPolicy: 'network-only',
  });

  if (loading) return <LoadingScreen />;
  if (error) return <ErrorScreen details={error.message} />;

  const invitation = data?.invitation;
  if (!invitation) return <ErrorScreen details="Invitation not found" />;

  const formatEventDateTime = (date: string, time: string, timezone?: string) => {
    const eventDate = new Date(date);
    const dateStr = eventDate.toLocaleDateString('en-US', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    });
    return `${dateStr} at ${time}${timezone ? ` (${timezone})` : ''}`;
  };

  return (
    <div className="min-h-screen bg-gray-50">
      <Toaster position="top-center" />

      {/* Header with back button */}
      <div className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <Button variant="ghost" onClick={() => navigate('/invitations')} className="mb-2">
            <ArrowLeft className="w-4 h-4 mr-2" />
            Back to Invitations
          </Button>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-6">
        {/* Cover Image */}
        {invitation.coverImageUrl && (
          <div className="w-full rounded-xl overflow-hidden shadow-lg">
            <img
              src={invitation.coverImageUrl}
              alt="Invitation cover"
              className="w-full h-64 object-cover"
            />
          </div>
        )}

        {/* Title Card */}
        <div className="bg-white rounded-xl shadow-sm p-6">
          <h1 className="text-3xl font-bold text-black mb-2">{invitation.title}</h1>
          {invitation.description && <p className="text-gray-600 mt-2">{invitation.description}</p>}
        </div>

        {/* Event Details */}
        <div className="bg-white rounded-xl shadow-sm p-6 space-y-4">
          <h2 className="text-xl font-bold text-black mb-4">Event Details</h2>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <div className="text-sm text-gray-500 mb-1">Date & Time</div>
              <div className="font-medium">
                {formatEventDateTime(
                  invitation.eventDate,
                  invitation.eventTime,
                  invitation.eventTimezone
                )}
              </div>
            </div>

            {invitation.location && (
              <div>
                <div className="text-sm text-gray-500 mb-1">Location</div>
                <div className="font-medium">{invitation.location}</div>
              </div>
            )}

            {invitation.attire && (
              <div>
                <div className="text-sm text-gray-500 mb-1">Attire</div>
                <div className="font-medium">{invitation.attire}</div>
              </div>
            )}

            <div>
              <div className="text-sm text-gray-500 mb-1">Created</div>
              <div className="font-medium">
                {new Date(invitation.createdAt).toLocaleDateString()}
              </div>
            </div>
          </div>

          {invitation.customInstructions && (
            <div className="mt-4 pt-4 border-t">
              <div className="text-sm text-gray-500 mb-1">Custom Instructions</div>
              <div className="font-medium whitespace-pre-wrap">{invitation.customInstructions}</div>
            </div>
          )}
        </div>

        {/* Owner Info */}
        <div className="bg-white rounded-xl shadow-sm p-6">
          <h2 className="text-xl font-bold text-black mb-4">Owner Information</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <div className="text-sm text-gray-500 mb-1">Name</div>
              <div className="font-medium">{invitation.user.name}</div>
            </div>
            <div>
              <div className="text-sm text-gray-500 mb-1">Email</div>
              <div className="font-medium">{invitation.user.email}</div>
            </div>
          </div>
        </div>

        {/* RSVP Summary */}
        <div className="bg-white rounded-xl shadow-sm p-6">
          <h2 className="text-xl font-bold text-black mb-4">RSVP Summary</h2>
          <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
            <div className="text-center">
              <div className="text-2xl font-bold text-green-600">{invitation.rsvpCounts.going}</div>
              <div className="text-sm text-gray-500 mt-1">Going</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-yellow-600">
                {invitation.rsvpCounts.maybe}
              </div>
              <div className="text-sm text-gray-500 mt-1">Maybe</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-gray-600">
                {invitation.rsvpCounts.notGoing}
              </div>
              <div className="text-sm text-gray-500 mt-1">Not Going</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-blue-600">{invitation.rsvpCounts.total}</div>
              <div className="text-sm text-gray-500 mt-1">Total RSVPs</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-purple-600">
                {invitation.rsvpCounts.totalAttendees}
              </div>
              <div className="text-sm text-gray-500 mt-1">Total Attendees</div>
            </div>
          </div>
        </div>

        {/* RSVP List */}
        <div className="bg-white rounded-xl shadow-sm p-6">
          <h2 className="text-xl font-bold text-black mb-4">RSVP List</h2>

          {invitation.rsvps.length === 0 ? (
            <div className="text-center py-8 text-gray-500">No RSVPs yet.</div>
          ) : (
            <>
              {/* Desktop Table View */}
              <div className="hidden md:block overflow-x-auto">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Guest</TableHead>
                      <TableHead>Email</TableHead>
                      <TableHead>Status</TableHead>
                      <TableHead>Additional Guests</TableHead>
                      <TableHead>Plus One</TableHead>
                      <TableHead>Message</TableHead>
                      <TableHead>RSVP Date</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {invitation.rsvps.map((rsvp: Rsvp) => (
                      <TableRow key={rsvp.id}>
                        <TableCell className="font-medium">
                          {rsvp.guestName || rsvp.user?.name || '-'}
                        </TableCell>
                        <TableCell>{rsvp.guestEmail || rsvp.user?.email || '-'}</TableCell>
                        <TableCell>
                          <span
                            className={clsx(
                              'px-2 py-1 rounded text-xs font-medium',
                              getStatusBadgeClass(rsvp.status)
                            )}
                          >
                            {formatStatus(rsvp.status)}
                          </span>
                        </TableCell>
                        <TableCell className="text-center">
                          {rsvp.additionalGuestsCount || 0}
                        </TableCell>
                        <TableCell>{rsvp.plusOneName || '-'}</TableCell>
                        <TableCell className="max-w-xs truncate">{rsvp.message || '-'}</TableCell>
                        <TableCell>{new Date(rsvp.createdAt).toLocaleDateString()}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </div>

              {/* Mobile Card View */}
              <div className="md:hidden space-y-4">
                {invitation.rsvps.map((rsvp: Rsvp) => (
                  <div key={rsvp.id} className="border rounded-lg p-4 space-y-2">
                    <div className="flex justify-between items-start">
                      <div className="font-medium">
                        {rsvp.guestName || rsvp.user?.name || 'Anonymous'}
                      </div>
                      <span
                        className={clsx(
                          'px-2 py-1 rounded text-xs font-medium',
                          getStatusBadgeClass(rsvp.status)
                        )}
                      >
                        {formatStatus(rsvp.status)}
                      </span>
                    </div>

                    {(rsvp.guestEmail || rsvp.user?.email) && (
                      <div className="text-sm text-gray-600">
                        {rsvp.guestEmail || rsvp.user?.email}
                      </div>
                    )}

                    {rsvp.additionalGuestsCount > 0 && (
                      <div className="text-sm">
                        <span className="text-gray-500">Additional Guests: </span>
                        <span className="font-medium">{rsvp.additionalGuestsCount}</span>
                      </div>
                    )}

                    {rsvp.plusOneName && (
                      <div className="text-sm">
                        <span className="text-gray-500">Plus One: </span>
                        <span className="font-medium">{rsvp.plusOneName}</span>
                      </div>
                    )}

                    {rsvp.message && (
                      <div className="text-sm pt-2 border-t">
                        <div className="text-gray-500 mb-1">Message:</div>
                        <div className="italic">{rsvp.message}</div>
                      </div>
                    )}

                    <div className="text-xs text-gray-500 pt-1">
                      RSVP on {new Date(rsvp.createdAt).toLocaleDateString()}
                    </div>
                  </div>
                ))}
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
