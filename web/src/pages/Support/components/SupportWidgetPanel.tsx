import { useState } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { MessageCircle, ListChecks } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import { Button } from '@/components/ui/button';
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from '@/components/ui/accordion';
import { faqs } from '@/config/faqs';
import NewTicketDialog from './NewTicketDialog';

interface SupportWidgetPanelProps {
  onNavigate: () => void;
}

/** The floating launcher's content: self-serve FAQ first, then a way to reach a human — a
 * new ticket for signed-in users, a sign-in prompt for everyone else, per the epic's
 * "no anonymous support path" decision (#213). Loaded lazily so the FAQ text, the ticket
 * mutation, and NewTicketDialog's own dependencies never enter the main bundle. */
export default function SupportWidgetPanel({ onNavigate }: SupportWidgetPanelProps) {
  const { user } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [newTicketOpen, setNewTicketOpen] = useState(false);

  const goSignIn = () => {
    const target = encodeURIComponent(`${location.pathname}${location.search}`);
    onNavigate();
    navigate(`/sign_in?redirect=${target}`);
  };

  const goToTicket = (externalId: string) => {
    onNavigate();
    navigate(`/support/${externalId}`);
  };

  return (
    <div className="flex flex-col gap-3">
      <div>
        <p className="font-semibold text-sm">Frequently asked questions</p>
        <p className="text-xs text-gray-500">Quick answers before you reach out.</p>
      </div>

      <Accordion type="single" collapsible className="w-full max-h-64 overflow-y-auto">
        {faqs.map((faq, index) => (
          <AccordionItem key={index} value={`item-${index}`}>
            <AccordionTrigger className="text-left text-sm py-2">{faq.question}</AccordionTrigger>
            <AccordionContent className="text-xs text-gray-600">{faq.answer}</AccordionContent>
          </AccordionItem>
        ))}
      </Accordion>

      <hr />

      {user ? (
        <div className="flex flex-col gap-2">
          <Button size="sm" className="w-full" onClick={() => setNewTicketOpen(true)}>
            <MessageCircle className="w-4 h-4" />
            Message us
          </Button>
          <Button
            size="sm"
            variant="outline"
            className="w-full"
            onClick={() => {
              onNavigate();
              navigate('/support');
            }}
          >
            <ListChecks className="w-4 h-4" />
            View my requests
          </Button>
        </div>
      ) : (
        <div className="space-y-2">
          <p className="text-xs text-gray-500">Sign in to start a conversation with us.</p>
          <Button size="sm" className="w-full" onClick={goSignIn}>
            Sign in to contact support
          </Button>
        </div>
      )}

      {user && (
        <NewTicketDialog
          open={newTicketOpen}
          onOpenChange={setNewTicketOpen}
          onCreated={ticket => goToTicket(ticket.externalId)}
        />
      )}
    </div>
  );
}
