import { useEffect, useState } from 'react';
import { useQuery } from '@apollo/client';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { LifeBuoy, Plus } from 'lucide-react';
import { formatDistanceToNow, parseISO } from 'date-fns';
import withAuth from '@/lib/with-auth';
import LoadingScreen from '@/components/Loading';
import ErrorScreen from '@/components/Error';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import NewTicketDialog from './components/NewTicketDialog';
import { MY_SUPPORT_TICKETS } from './queries';
import { STATUS_LABELS, lastActivityAt, statusBadgeVariant } from './types';
import type { SupportTicketSummary } from './types';

interface MySupportTicketsResponse {
  mySupportTickets: { supportTickets: SupportTicketSummary[] };
}

function SupportIndex() {
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const { data, loading, error, refetch } = useQuery<MySupportTicketsResponse>(MY_SUPPORT_TICKETS, {
    fetchPolicy: 'cache-and-network',
  });

  const [newTicketOpen, setNewTicketOpen] = useState(false);

  // `/support?new=1` opens the compose form directly — that's what Profile.tsx's
  // "Contact Us" button links to, so it reaches the new flow in one click rather
  // than landing on the list first.
  useEffect(() => {
    if (searchParams.get('new') === '1') {
      setNewTicketOpen(true);
      searchParams.delete('new');
      setSearchParams(searchParams, { replace: true });
    }
  }, [searchParams, setSearchParams]);

  if (loading && !data) return <LoadingScreen />;
  if (error) return <ErrorScreen details="Failed to load your support tickets" />;

  const tickets = data?.mySupportTickets.supportTickets ?? [];

  return (
    <div className="flex flex-col flex-grow min-h-[calc(100vh-4rem)] p-4">
      <div className="w-full max-w-3xl mx-auto px-4 py-6 mt-8 space-y-6">
        <div className="flex items-center justify-between">
          <h2 className="text-2xl font-bold">Support</h2>
          <Button onClick={() => setNewTicketOpen(true)}>
            <Plus className="w-4 h-4" />
            New request
          </Button>
        </div>

        {tickets.length === 0 ? (
          <Card className="shadow-md rounded-xl">
            <CardContent className="flex flex-col items-center text-center gap-4 py-12">
              <LifeBuoy className="w-10 h-10 text-gray-400" />
              <div className="space-y-1">
                <p className="text-lg font-semibold">No support requests yet</p>
                <p className="text-sm text-gray-500 max-w-sm">
                  Questions about your account, credits, or a card? Send us a message and we'll
                  reply here.
                </p>
              </div>
              <Button onClick={() => setNewTicketOpen(true)}>
                <Plus className="w-4 h-4" />
                New request
              </Button>
            </CardContent>
          </Card>
        ) : (
          <div className="space-y-3">
            {tickets.map(ticket => (
              <Link key={ticket.id} to={`/support/${ticket.externalId}`}>
                <Card className="shadow-sm rounded-xl hover:shadow-md transition-shadow">
                  <CardContent className="flex items-center justify-between gap-4 py-4">
                    <div className="min-w-0 space-y-1">
                      <p className="font-medium text-black truncate">{ticket.subject}</p>
                      <p className="text-sm text-gray-500">{ticket.category}</p>
                    </div>
                    <div className="flex flex-col items-end gap-1 shrink-0">
                      <Badge variant={statusBadgeVariant(ticket.status)}>
                        {STATUS_LABELS[ticket.status] ?? ticket.status}
                      </Badge>
                      <p className="text-xs text-gray-400">
                        {formatDistanceToNow(parseISO(lastActivityAt(ticket)), { addSuffix: true })}
                      </p>
                    </div>
                  </CardContent>
                </Card>
              </Link>
            ))}
          </div>
        )}
      </div>

      <NewTicketDialog
        open={newTicketOpen}
        onOpenChange={setNewTicketOpen}
        onCreated={ticket => {
          refetch();
          navigate(`/support/${ticket.externalId}`);
        }}
      />
    </div>
  );
}

export default withAuth(SupportIndex);
