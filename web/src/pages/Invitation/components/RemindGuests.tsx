/**
 * Lets an invitation's host email a reminder to the guests who RSVPed (#319). Only going / maybe
 * guests can be written to: they are the ones who left an address. The server enforces the real
 * rules (host only, one a day, not after the event); the form mirrors them so the button says why
 * it is off instead of failing after a click.
 */
import React, { useState } from 'react';
import { gql, useMutation } from '@apollo/client';
import { toast } from 'sonner';
import { BellRing } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Textarea } from '@/components/ui/textarea';

const SEND_INVITATION_REMINDER = gql`
  mutation SendInvitationReminder($input: SendInvitationReminderInput!) {
    sendInvitationReminder(input: $input) {
      sentCount
      invitation {
        id
        reminderSentAt
        nextReminderAt
      }
      errors
    }
  }
`;

const NOTE_MAX_LENGTH = 500;

type Audience = 'going_and_maybe' | 'going' | 'maybe';

interface Props {
  invitationExternalId: string;
  // yyyy-mm-dd, as the API sends it.
  eventDate: string;
  going: number;
  maybe: number;
  nextReminderAt?: string | null;
}

const isPast = (eventDate: string) => {
  const today = new Date();
  const [year, month, day] = eventDate.split('-').map(Number);
  return (
    new Date(year, month - 1, day) <
    new Date(today.getFullYear(), today.getMonth(), today.getDate())
  );
};

const RemindGuests: React.FC<Props> = ({
  invitationExternalId,
  eventDate,
  going,
  maybe,
  nextReminderAt,
}) => {
  const [audience, setAudience] = useState<Audience>('going_and_maybe');
  const [note, setNote] = useState('');
  const [send, { loading }] = useMutation(SEND_INVITATION_REMINDER);

  const counts: Record<Audience, number> = { going_and_maybe: going + maybe, going, maybe };
  const recipients = counts[audience];
  const past = isPast(eventDate);
  const waitingUntil = nextReminderAt ? new Date(nextReminderAt) : null;
  const tooSoon = waitingUntil !== null && waitingUntil.getTime() > Date.now();

  const disabledReason = past
    ? 'The event has already happened.'
    : tooSoon
      ? `You sent a reminder recently. You can send another after ${waitingUntil!.toLocaleString([], { dateStyle: 'medium', timeStyle: 'short' })}.`
      : recipients === 0
        ? 'No one has RSVPed this way yet.'
        : null;

  const handleSend = async () => {
    try {
      const { data } = await send({
        variables: { input: { externalId: invitationExternalId, audience, note: note.trim() } },
      });
      const result = data?.sendInvitationReminder;
      if (result?.errors?.length) {
        toast.error(result.errors.join(', '));
        return;
      }
      toast.success(
        `Reminder sent to ${result.sentCount} ${result.sentCount === 1 ? 'guest' : 'guests'}`
      );
      setNote('');
    } catch (e) {
      console.error('Failed to send reminder', e);
      toast.error('Failed to send the reminder.');
    }
  };

  const options: { value: Audience; label: string }[] = [
    { value: 'going_and_maybe', label: `Going and maybe (${counts.going_and_maybe})` },
    { value: 'going', label: `Going (${counts.going})` },
    { value: 'maybe', label: `Maybe (${counts.maybe})` },
  ];

  return (
    <Card className="mt-8">
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <BellRing className="h-5 w-5 text-gray-600" />
          Remind guests
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <fieldset className="space-y-2">
          <legend className="mb-1 text-sm font-medium text-gray-700">Send to</legend>
          {options.map(option => (
            <label key={option.value} className="flex cursor-pointer items-center gap-2 text-sm">
              <input
                type="radio"
                name="reminder-audience"
                value={option.value}
                checked={audience === option.value}
                onChange={() => setAudience(option.value)}
              />
              {option.label}
            </label>
          ))}
        </fieldset>

        <div className="space-y-1">
          <label htmlFor="reminder-note" className="text-sm font-medium text-gray-700">
            Add a note (optional)
          </label>
          <Textarea
            id="reminder-note"
            value={note}
            maxLength={NOTE_MAX_LENGTH}
            rows={3}
            placeholder="Parking is on the left. Can't wait to see you!"
            onChange={e => setNote(e.target.value)}
            className="border-2"
          />
          <p className="text-xs text-gray-500">
            {note.length}/{NOTE_MAX_LENGTH}. Going guests also get the add-to-calendar buttons
            again. One reminder per day.
          </p>
        </div>

        <Button
          onClick={handleSend}
          disabled={loading || disabledReason !== null}
          className="w-full sm:w-auto"
        >
          {loading
            ? 'Sending...'
            : `Send reminder to ${recipients} ${recipients === 1 ? 'guest' : 'guests'}`}
        </Button>
        {disabledReason && <p className="text-sm text-gray-600">{disabledReason}</p>}
      </CardContent>
    </Card>
  );
};

export default RemindGuests;
