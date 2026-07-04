import React, { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Card } from '@/components/ui/card';
import { RSVPStatus } from '@/types/app';
import { toast } from 'sonner';

interface ExistingRsvp {
  id: string;
  guestName: string;
  guestEmail: string;
  status: string;
  plusOne: boolean;
  additionalGuestsCount?: number;
  plusOneName?: string | null;
  message?: string | null;
}

interface RSVPFormProps {
  invitationId: string;
  maxAdditionalGuests: number;
  onSubmit: (data: {
    status: RSVPStatus;
    guestName: string;
    guestEmail: string;
    plusOne: boolean;
    additionalGuestsCount: number;
    plusOneName?: string;
    message?: string;
  }) => Promise<void>;
  existingRsvp?: ExistingRsvp | null;
  defaultName?: string;
  defaultEmail?: string;
}

const RSVPForm: React.FC<RSVPFormProps> = ({
  maxAdditionalGuests,
  onSubmit,
  existingRsvp,
  defaultName = '',
  defaultEmail = '',
}) => {
  const [selectedStatus, setSelectedStatus] = useState<RSVPStatus | null>(
    existingRsvp ? (existingRsvp.status as RSVPStatus) : null
  );
  const [guestName, setGuestName] = useState(existingRsvp?.guestName || defaultName);
  const [guestEmail, setGuestEmail] = useState(existingRsvp?.guestEmail || defaultEmail);
  const [additionalGuestsCount, setAdditionalGuestsCount] = useState(
    existingRsvp?.additionalGuestsCount || 0
  );
  const [plusOneName, setPlusOneName] = useState(existingRsvp?.plusOneName || '');
  const [message, setMessage] = useState(existingRsvp?.message || '');
  const isUpdate = !!existingRsvp;
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async () => {
    if (!selectedStatus) {
      toast.error('Please select your RSVP status');
      return;
    }

    if (!guestName.trim() || !guestEmail.trim()) {
      toast.error('Please enter your name and email');
      return;
    }

    if (additionalGuestsCount > 0 && !plusOneName.trim()) {
      toast.error('Please enter the name(s) of your additional guest(s)');
      return;
    }

    setSubmitting(true);

    try {
      await onSubmit({
        status: selectedStatus,
        guestName,
        guestEmail,
        plusOne: additionalGuestsCount > 0,
        additionalGuestsCount,
        plusOneName: additionalGuestsCount > 0 ? plusOneName : undefined,
        message: message.trim() || undefined,
      });

      toast.success(isUpdate ? 'Response updated' : 'Response submitted');
    } catch (error) {
      toast.error(
        isUpdate ? 'Failed to update. Please try again.' : 'Failed to submit. Please try again.'
      );
      console.error(error);
    } finally {
      setSubmitting(false);
    }
  };

  const rsvpOptions = [
    {
      status: 'going' as RSVPStatus,
      emoji: '✓',
      label: 'Going',
      color: 'from-green-500 to-emerald-600',
      ringColor: 'ring-green-500',
    },
    {
      status: 'maybe' as RSVPStatus,
      emoji: '?',
      label: 'Maybe',
      color: 'from-amber-400 to-orange-500',
      ringColor: 'ring-amber-500',
    },
    {
      status: 'not-going' as RSVPStatus,
      emoji: '✗',
      label: "Can't Go",
      color: 'from-gray-400 to-gray-500',
      ringColor: 'ring-gray-400',
    },
  ];

  return (
    <Card className="p-6 space-y-6 bg-white/95 backdrop-blur border-2">
      <div>
        <h3 className="text-xl font-semibold mb-4 text-center text-gray-800">
          {isUpdate ? 'Update your response' : 'Will you be joining us?'}
        </h3>

        {/* RSVP Status Buttons */}
        <div className="grid grid-cols-3 gap-2 sm:gap-3">
          {rsvpOptions.map(option => (
            <button
              key={option.status}
              onClick={() => setSelectedStatus(option.status)}
              className={`
                relative flex flex-col items-center justify-center
                h-24 sm:h-28 rounded-xl sm:rounded-2xl transition-all duration-200
                ${
                  selectedStatus === option.status
                    ? `bg-gradient-to-br ${option.color} text-white shadow-lg ring-2 ring-offset-2 ${option.ringColor}`
                    : 'bg-white border-2 border-gray-200 hover:border-gray-300 hover:shadow-md'
                }
              `}
            >
              <div className="text-2xl sm:text-3xl mb-1">{option.emoji}</div>
              <div
                className={`font-semibold text-sm sm:text-base ${selectedStatus !== option.status ? 'text-gray-700' : ''}`}
              >
                {option.label}
              </div>
            </button>
          ))}
        </div>
      </div>

      {selectedStatus && (
        <div className="space-y-4 animate-in fade-in slide-in-from-top-4 duration-300">
          {/* Guest Info */}
          <div className="space-y-2">
            <Label htmlFor="guestName" className="font-semibold">
              Your Name *
            </Label>
            <Input
              id="guestName"
              placeholder="John Doe"
              value={guestName}
              onChange={e => setGuestName(e.target.value)}
              className="border-2"
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="guestEmail" className="font-semibold">
              Email *
            </Label>
            <Input
              id="guestEmail"
              type="email"
              placeholder="john@example.com"
              value={guestEmail}
              onChange={e => setGuestEmail(e.target.value)}
              className="border-2"
            />
          </div>

          {/* Additional Guests Section */}
          {maxAdditionalGuests > 0 && selectedStatus === 'going' && (
            <div className="border-2 border-dashed border-purple-300 rounded-xl p-4 bg-purple-50/50 space-y-3">
              <div className="flex items-center justify-between">
                <div>
                  <Label className="font-semibold">Bringing additional guests?</Label>
                  <p className="text-sm text-gray-600">
                    You can bring up to {maxAdditionalGuests} additional{' '}
                    {maxAdditionalGuests === 1 ? 'guest' : 'guests'}
                  </p>
                </div>
                <select
                  value={additionalGuestsCount}
                  onChange={e => setAdditionalGuestsCount(parseInt(e.target.value))}
                  className="h-10 px-3 rounded-md border-2 border-input bg-white focus:border-purple-400 focus:outline-none"
                >
                  <option value={0}>No</option>
                  {Array.from({ length: maxAdditionalGuests }, (_, i) => i + 1).map(num => (
                    <option key={num} value={num}>
                      {num} {num === 1 ? 'guest' : 'guests'}
                    </option>
                  ))}
                </select>
              </div>

              {additionalGuestsCount > 0 && (
                <div className="space-y-2 animate-in fade-in slide-in-from-top-2 duration-200">
                  <Label htmlFor="plusOneName" className="font-semibold">
                    {additionalGuestsCount === 1 ? "Guest's Name *" : "Guests' Names *"}
                  </Label>
                  <Input
                    id="plusOneName"
                    placeholder={
                      additionalGuestsCount === 1 ? 'Jane Smith' : 'Jane Smith, John Doe'
                    }
                    value={plusOneName}
                    onChange={e => setPlusOneName(e.target.value)}
                    className="bg-white border-2"
                  />
                </div>
              )}
            </div>
          )}

          {/* Message */}
          <div className="space-y-2">
            <Label htmlFor="message" className="font-semibold">
              Message to Host (Optional)
            </Label>
            <Textarea
              id="message"
              placeholder="Leave a note for the host..."
              value={message}
              onChange={e => setMessage(e.target.value)}
              rows={3}
              className="border-2 resize-none"
            />
          </div>

          {/* Submit Button */}
          <Button
            onClick={handleSubmit}
            disabled={submitting}
            className="w-full bg-gray-900 hover:bg-gray-800 text-white font-medium text-base py-6 shadow-md hover:shadow-lg transition-all"
          >
            {submitting
              ? isUpdate
                ? 'Updating...'
                : 'Submitting...'
              : isUpdate
                ? 'Update Response'
                : 'Confirm'}
          </Button>
        </div>
      )}
    </Card>
  );
};

export default RSVPForm;
