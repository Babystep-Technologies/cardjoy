import { useQuery, gql } from '@apollo/client';
import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { Toaster } from 'sonner';
import withAuth from '@/lib/with-auth';
import LoadingScreen from '@/components/Loading';
import ErrorScreen from '@/components/Error';
import { Invitation } from '@/types/app';

const GET_ADMIN_INVITATIONS = gql`
  query GetAdminInvitations($page: Int!, $perPage: Int!, $search: String) {
    adminInvitations(page: $page, perPage: $perPage, search: $search) {
      invitations {
        id
        externalId
        title
        location
        eventDate
        eventTime
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
      }
      totalCount
      currentPage
      perPage
    }
  }
`;

const ManageInvitations: React.FC = () => {
  const navigate = useNavigate();
  const [search, setSearch] = useState('');
  const [searchInput, setSearchInput] = useState('');
  const [page, setPage] = useState(1);

  const { data, loading, error, refetch } = useQuery(GET_ADMIN_INVITATIONS, {
    variables: { page, perPage: 25, search },
  });

  const invitations = data?.adminInvitations.invitations || [];
  const totalPages = Math.ceil((data?.adminInvitations.totalCount || 0) / 25);

  useEffect(() => {
    refetch();
  }, [page, search, refetch]);

  if (loading) return <LoadingScreen />;
  if (error) return <ErrorScreen details={error.message} />;

  const formatEventDateTime = (date: string, time: string) => {
    const eventDate = new Date(date);
    return `${eventDate.toLocaleDateString()} at ${time}`;
  };

  return (
    <div className="flex flex-col min-h-[calc(100vh-80px)] space-y-6">
      <Toaster />

      <div className="flex justify-between items-center">
        <h2 className="text-2xl font-bold text-black">Manage Invitations</h2>
      </div>

      <form
        className="flex items-center gap-3 mb-4"
        onSubmit={e => {
          e.preventDefault();
          setSearch(searchInput);
        }}
      >
        <Input
          placeholder="Search by invitation title..."
          value={searchInput}
          onChange={e => setSearchInput(e.target.value)}
          className="bg-white w-full max-w-md"
        />
        <Button type="submit">Search</Button>
        <Button
          type="button"
          variant="ghost"
          onClick={() => {
            setSearchInput('');
            setSearch('');
          }}
        >
          Reset
        </Button>
      </form>

      {/* Desktop Table View */}
      <div className="hidden md:block flex-1 overflow-auto">
        <Table className="bg-white rounded-xl shadow-sm min-h-[400px] w-full">
          <TableHeader>
            <TableRow>
              <TableHead className="text-center">Title</TableHead>
              <TableHead className="text-center">Event Date</TableHead>
              <TableHead className="text-center">Location</TableHead>
              <TableHead className="text-center">RSVPs</TableHead>
              <TableHead className="text-center">Total Attendees</TableHead>
              <TableHead className="text-center">Owner</TableHead>
              <TableHead className="text-center">Created</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {invitations.length === 0 ? (
              <TableRow>
                <TableCell colSpan={7} className="text-center py-6 text-gray-500">
                  No invitations found.
                </TableCell>
              </TableRow>
            ) : (
              invitations.map((invitation: Invitation) => (
                <TableRow
                  key={invitation.id}
                  className="cursor-pointer hover:bg-gray-50"
                  onClick={() => navigate(`/invitation/${invitation.externalId}`)}
                >
                  <TableCell className="text-center align-top pt-4 font-medium">
                    {invitation.title}
                  </TableCell>
                  <TableCell className="text-center align-top pt-4">
                    {formatEventDateTime(invitation.eventDate, invitation.eventTime)}
                  </TableCell>
                  <TableCell className="text-center align-top pt-4">
                    {invitation.location || '-'}
                  </TableCell>
                  <TableCell className="text-center align-top pt-4">
                    <div className="flex justify-center gap-1">
                      <span className="px-2 py-1 rounded text-xs font-medium bg-green-100 text-green-800">
                        {invitation.rsvpCounts.going} Going
                      </span>
                      <span className="px-2 py-1 rounded text-xs font-medium bg-yellow-100 text-yellow-800">
                        {invitation.rsvpCounts.maybe} Maybe
                      </span>
                      <span className="px-2 py-1 rounded text-xs font-medium bg-gray-100 text-gray-700">
                        {invitation.rsvpCounts.notGoing} Not Going
                      </span>
                    </div>
                  </TableCell>
                  <TableCell className="text-center align-top pt-4">
                    {invitation.rsvpCounts.totalAttendees}
                  </TableCell>
                  <TableCell className="text-center align-top pt-4">
                    <div className="text-sm">
                      <div className="font-medium">{invitation.user.name}</div>
                      <div className="text-gray-500">{invitation.user.email}</div>
                    </div>
                  </TableCell>
                  <TableCell className="text-center align-top pt-4">
                    {new Date(invitation.createdAt).toLocaleDateString()}
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </div>

      {/* Mobile Card View */}
      <div className="md:hidden divide-y bg-white rounded-xl shadow-sm min-h-[400px]">
        {invitations.length === 0 ? (
          <div className="flex justify-center items-center h-48">
            <p className="text-gray-500">No invitations found.</p>
          </div>
        ) : (
          invitations.map((invitation: Invitation) => (
            <div
              key={invitation.id}
              className="p-4 space-y-3 cursor-pointer hover:bg-gray-50"
              onClick={() => navigate(`/invitation/${invitation.externalId}`)}
            >
              <div className="font-medium text-lg text-black">{invitation.title}</div>

              <div className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <span className="text-gray-500">Event:</span>
                  <span className="font-medium">
                    {formatEventDateTime(invitation.eventDate, invitation.eventTime)}
                  </span>
                </div>

                {invitation.location && (
                  <div className="flex justify-between">
                    <span className="text-gray-500">Location:</span>
                    <span className="font-medium">{invitation.location}</span>
                  </div>
                )}

                <div className="flex justify-between items-center">
                  <span className="text-gray-500">RSVPs:</span>
                  <div className="flex gap-1">
                    <span className="px-2 py-1 rounded text-xs font-medium bg-green-100 text-green-800">
                      {invitation.rsvpCounts.going}
                    </span>
                    <span className="px-2 py-1 rounded text-xs font-medium bg-yellow-100 text-yellow-800">
                      {invitation.rsvpCounts.maybe}
                    </span>
                    <span className="px-2 py-1 rounded text-xs font-medium bg-gray-100 text-gray-700">
                      {invitation.rsvpCounts.notGoing}
                    </span>
                  </div>
                </div>

                <div className="flex justify-between">
                  <span className="text-gray-500">Total Attendees:</span>
                  <span className="font-medium">{invitation.rsvpCounts.totalAttendees}</span>
                </div>

                <div className="flex justify-between">
                  <span className="text-gray-500">Owner:</span>
                  <span className="font-medium">{invitation.user.name}</span>
                </div>

                <div className="flex justify-between">
                  <span className="text-gray-500">Created:</span>
                  <span className="font-medium">
                    {new Date(invitation.createdAt).toLocaleDateString()}
                  </span>
                </div>
              </div>
            </div>
          ))
        )}
      </div>

      <div className="flex justify-center items-center gap-2 mt-auto pb-4">
        <Button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1}>
          Prev
        </Button>
        <span className="text-sm text-gray-600">
          Page {page} of {totalPages}
        </span>
        <Button
          onClick={() => setPage(p => Math.min(totalPages, p + 1))}
          disabled={page === totalPages}
        >
          Next
        </Button>
      </div>
    </div>
  );
};

export default withAuth(ManageInvitations);
