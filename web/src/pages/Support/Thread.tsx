import { useState } from 'react';
import { useMutation, useQuery } from '@apollo/client';
import { useNavigate, useParams } from 'react-router-dom';
import { ArrowLeft } from 'lucide-react';
import { format, parseISO } from 'date-fns';
import { toast } from 'sonner';
import withAuth from '@/lib/with-auth';
import LoadingScreen from '@/components/Loading';
import ErrorScreen from '@/components/Error';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Textarea } from '@/components/ui/textarea';
import { cn } from '@/lib/utils';
import { REPLY_TO_SUPPORT_TICKET, SUPPORT_TICKET } from './queries';
import { STATUS_LABELS, statusBadgeVariant } from './types';
import type { SupportTicketDetail } from './types';

interface SupportTicketResponse {
  supportTicket: SupportTicketDetail | null;
}

function SupportThread() {
  const { externalId = '' } = useParams<{ externalId: string }>();
  const navigate = useNavigate();
  const [reply, setReply] = useState('');

  const { data, loading, error, refetch } = useQuery<SupportTicketResponse>(SUPPORT_TICKET, {
    variables: { externalId },
    fetchPolicy: 'cache-and-network',
  });

  const [replyToSupportTicket, { loading: replying }] = useMutation(REPLY_TO_SUPPORT_TICKET);

  if (loading && !data) return <LoadingScreen />;
  if (error) return <ErrorScreen details="Failed to load this support request" />;

  const ticket = data?.supportTicket;
  if (!ticket) {
    return (
      <ErrorScreen
        message="Support request not found"
        action={<Button onClick={() => navigate('/support')}>Back to support</Button>}
      />
    );
  }

  const handleReply = async () => {
    if (!reply.trim()) return;

    try {
      const { data: result } = await replyToSupportTicket({
        variables: { input: { ticketExternalId: externalId, body: reply.trim() } },
      });
      const errors = result?.replyToSupportTicket?.errors;
      if (errors?.length) {
        toast.error(errors.join(', '));
        return;
      }

      setReply('');
      await refetch();
    } catch (err) {
      toast.error(`Something went wrong: ${(err as Error).message}`);
    }
  };

  return (
    <div className="flex flex-col flex-grow min-h-[calc(100vh-4rem)] p-4">
      <div className="w-full max-w-3xl mx-auto px-4 py-6 mt-8 space-y-4 flex-1 flex flex-col">
        <Button variant="outline" className="self-start" onClick={() => navigate('/support')}>
          <ArrowLeft className="w-4 h-4" />
          Back to support
        </Button>

        <div className="flex items-start justify-between gap-4">
          <div className="min-w-0">
            <h2 className="text-2xl font-bold truncate">{ticket.subject}</h2>
            <p className="text-sm text-gray-500">{ticket.category}</p>
          </div>
          <Badge variant={statusBadgeVariant(ticket.status)} className="shrink-0">
            {STATUS_LABELS[ticket.status] ?? ticket.status}
          </Badge>
        </div>

        <div className="flex-1 space-y-4 overflow-y-auto py-2">
          {ticket.messages.map(message => {
            const isCustomer = message.authorKind === 'customer';
            const isSystem = message.authorKind === 'system';

            if (isSystem) {
              return (
                <p key={message.id} className="text-center text-xs text-gray-400">
                  {message.body}
                </p>
              );
            }

            return (
              <div
                key={message.id}
                className={cn('flex flex-col gap-1', isCustomer ? 'items-end' : 'items-start')}
              >
                <Card
                  className={cn(
                    'max-w-[85%] sm:max-w-[70%] shadow-sm rounded-xl',
                    isCustomer ? 'bg-black text-white' : 'bg-gray-100 text-black'
                  )}
                >
                  <CardContent className="py-3 px-4 whitespace-pre-wrap break-words">
                    {message.body}
                  </CardContent>
                </Card>
                <p className="text-xs text-gray-400 px-1">
                  {isCustomer ? 'You' : (message.authorName ?? 'CardJoy Support')} &middot;{' '}
                  {format(parseISO(message.createdAt), 'MMM d, h:mm a')}
                </p>
              </div>
            );
          })}
        </div>

        <div className="space-y-2 border-t border-gray-200 pt-4">
          <Textarea
            value={reply}
            onChange={e => setReply(e.target.value)}
            placeholder="Write a reply..."
            rows={4}
            className="w-full"
          />
          <Button
            onClick={handleReply}
            disabled={replying || !reply.trim()}
            className="w-full sm:w-auto"
          >
            {replying ? 'Sending...' : 'Send reply'}
          </Button>
        </div>
      </div>
    </div>
  );
}

export default withAuth(SupportThread);
