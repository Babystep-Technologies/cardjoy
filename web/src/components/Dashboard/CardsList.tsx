import React, { useState } from 'react';
import { useMutation } from '@apollo/client';
import { useNavigate } from 'react-router-dom';
import { gql } from '@apollo/client';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Card, CardContent } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { Sheet, SheetContent, SheetHeader, SheetTitle } from '@/components/ui/sheet';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
} from '@/components/ui/dropdown-menu';
import {
  MoreHorizontal,
  Lock,
  Edit2,
  Eye,
  Send,
  Unlock,
  QrCode,
  RotateCcw,
  CalendarClock,
  XCircle,
} from 'lucide-react';
import * as motion from 'motion/react-client';
import { format } from 'date-fns';
import { isMobile } from '@/lib/utils';
import { CardType } from '@/types/app';
import {
  detectTimezone,
  formatInTimezone,
  utcToZonedParts,
  zonedWallTimeToUtcISO,
} from '@/lib/timezone';
import SchedulePicker from '@/pages/Card/components/SchedulePicker';
import { toast } from 'sonner';

const TOGGLE_LOCK_CARD = gql`
  mutation ToggleLockCard($input: ToggleLockCardInput!) {
    toggleLockCard(input: $input) {
      success
    }
  }
`;

const DELIVER_CARD = gql`
  mutation DeliverCard($input: DeliverCardInput!) {
    deliverCard(input: $input) {
      card {
        externalId
        deliverAt
      }
      errors
    }
  }
`;

const CANCEL_SCHEDULED_DELIVERY = gql`
  mutation CancelScheduledDelivery($input: CancelScheduledDeliveryInput!) {
    cancelScheduledDelivery(input: $input) {
      card {
        externalId
      }
      errors
    }
  }
`;

// A card with a `deliverAt` still in the future has a pending scheduled send.
const pendingScheduledSend = (card: CardType): string | null => {
  if (!card.deliverAt) return null;
  return new Date(card.deliverAt).getTime() > Date.now() ? card.deliverAt : null;
};

// Custom hook to handle image loading state
const useImageLoader = (src: string | null) => {
  const [loading, setLoading] = useState(!!src);
  const [error, setError] = useState(false);
  const [retryKey, setRetryKey] = useState(0);

  React.useEffect(() => {
    if (!src) {
      setLoading(false);
      setError(false);
      return;
    }

    setLoading(true);
    setError(false);

    const img = new Image();
    img.onload = () => {
      setLoading(false);
      setError(false);
    };
    img.onerror = () => {
      setLoading(false);
      setError(true);
    };
    img.src = `${src}?retry=${retryKey}`;

    return () => {
      img.onload = null;
      img.onerror = null;
    };
  }, [src, retryKey]);

  const retry = () => {
    setRetryKey(prev => prev + 1);
  };

  return { loading, error, retry };
};

// Component to render a card with image loading state
// Who to credit an organization-owned card to, or null when the card is personal and
// the question doesn't arise. "You" rather than your own name — it reads as a list of
// the team's cards with yours marked, which is what it is.
// Compared as strings: the JWT carries `user_id` as a number while GraphQL hands back
// an ID string, so `===` on the raw values never matches your own card.
const creatorLabel = (card: CardType, currentUserId: string | null): string | null => {
  if (!card.organization || !card.user) return null;
  return String(card.user.id) === String(currentUserId) ? 'you' : card.user.name;
};

const CardWithImageLoader: React.FC<{
  card: CardType;
  creator: string | null;
  onEdit: (id: string) => void;
  onShare: (id: string) => void;
  onPreview: (id: string) => void;
  onQr: (id: string) => void;
  onToggleLock: (id: string) => void;
  onDelete: (id: string) => void;
  onEditSchedule: (card: CardType) => void;
  onCancelSchedule: (card: CardType) => void;
  onOpenSheet: (id: string) => void;
  openSheetCardId: string | null;
  navigate: (path: string) => void;
}> = ({
  card,
  creator,
  onEdit,
  onShare,
  onPreview,
  onQr,
  onToggleLock,
  onDelete,
  onEditSchedule,
  onCancelSchedule,
  onOpenSheet,
  openSheetCardId,
  navigate,
}) => {
  const { loading, error, retry } = useImageLoader(card.coverImageUrl || null);
  const scheduledAt = pendingScheduledSend(card);

  if (loading) {
    return (
      <Card
        className="relative min-h-[200px] max-w-[600px] w-full mx-auto overflow-hidden p-0"
        style={{
          aspectRatio: '4/3',
          maxHeight: '25vh',
        }}
      >
        <Skeleton className="w-full h-full bg-gray-200 dark:bg-gray-700" />
      </Card>
    );
  }

  if (error) {
    return (
      <Card
        className="relative min-h-[200px] max-w-[600px] w-full mx-auto overflow-hidden flex items-center justify-center bg-gray-100 dark:bg-gray-800"
        style={{
          aspectRatio: '4/3',
          maxHeight: '25vh',
        }}
      >
        <div className="text-center p-4">
          <div className="text-gray-400 mb-3 text-sm">Failed to load background image</div>
          <Button variant="outline" size="sm" onClick={retry} className="gap-2">
            <RotateCcw className="h-4 w-4" />
            Retry
          </Button>
        </div>
      </Card>
    );
  }

  return (
    <Card
      style={{
        backgroundImage: card.coverImageUrl ? `url(${card.coverImageUrl})` : undefined,
        backgroundSize: 'cover',
        backgroundPosition: 'center',
        backgroundColor: card.coverImageUrl ? undefined : 'black',
        aspectRatio: '4/3',
        maxHeight: '25vh',
      }}
      className="relative min-h-[200px] max-w-[600px] w-full mx-auto overflow-hidden"
    >
      <CardContent
        className="relative z-10 flex flex-col h-full text-white cursor-pointer"
        onClick={() => navigate(`/card/${card.externalId}/editable`)}
      >
        {card.locked && (
          <div className="absolute top-0 right-8 z-10">
            <Lock className="w-6 h-6 text-white opacity-90" />
          </div>
        )}

        {scheduledAt && (
          <div className="absolute top-3 left-3 z-10">
            <Badge className="gap-1 bg-blue-600 text-white shadow">
              <CalendarClock className="h-3 w-3" />
              {formatInTimezone(scheduledAt, detectTimezone())}
            </Badge>
          </div>
        )}

        <div className="bg-white/90 text-black text-center px-4 py-3 rounded-md shadow-md mx-auto w-[80%] max-w-[90%] overflow-hidden">
          <h2 className="font-bold text-lg truncate">{card.title}</h2>
          {card.recipients?.length > 0 && (
            <p className="text-sm font-medium mt-1 truncate">For: {card.recipients.join(', ')}</p>
          )}
          {scheduledAt && card.deliverToEmail && (
            <p className="text-xs text-gray-600 mt-1 truncate">Sending to {card.deliverToEmail}</p>
          )}
          {creator && <p className="text-xs text-gray-600 mt-1 truncate">Created by {creator}</p>}
        </div>

        <div className="mt-auto pt-4 flex justify-end" onClick={e => e.stopPropagation()}>
          {isMobile() ? (
            <>
              <Button
                size="icon"
                className="bg-white text-black rounded-full shadow hover:bg-gray-100 p-2"
                onClick={() => onOpenSheet(card.externalId)}
              >
                <MoreHorizontal className="w-4 h-4" />
              </Button>
              <Sheet
                open={openSheetCardId === card.externalId}
                onOpenChange={() => onOpenSheet('')}
              >
                <SheetContent side="bottom" className="text-black space-y-4 p-4 pb-12">
                  <motion.div
                    key="mobile-sheet"
                    initial={{ opacity: 0, scale: 0.95 }}
                    animate={{ opacity: 1, scale: 1 }}
                    exit={{ opacity: 0, scale: 0.95 }}
                    transition={{
                      duration: 0.25,
                      ease: 'easeOut',
                    }}
                    className="text-black space-y-4 p-4 pb-12"
                  >
                    <SheetHeader>
                      <SheetTitle>Card Options</SheetTitle>
                    </SheetHeader>
                    <Button
                      variant="ghost"
                      className="w-full justify-start"
                      onClick={() => onEdit(card.externalId)}
                    >
                      <Edit2 className="w-4 h-4 mr-2" /> Edit
                    </Button>
                    <Button
                      variant="ghost"
                      className="w-full justify-start"
                      onClick={() => {
                        onOpenSheet('');
                        onShare(card.externalId);
                      }}
                    >
                      <Send className="w-4 h-4 mr-2" /> Share
                    </Button>
                    <Button
                      variant="ghost"
                      className="w-full justify-start"
                      onClick={() => onPreview(card.externalId)}
                    >
                      <Eye className="w-4 h-4 mr-2" /> Preview
                    </Button>
                    <Button
                      variant="ghost"
                      className="w-full justify-start"
                      onClick={() => onQr(card.externalId)}
                    >
                      <QrCode className="w-4 h-4 mr-2" /> Show QR Code
                    </Button>
                    <Button
                      variant="ghost"
                      className="w-full justify-start"
                      onClick={() => onToggleLock(card.externalId)}
                    >
                      {card.locked ? (
                        <>
                          <Unlock className="w-4 h-4 mr-2" /> Unlock
                        </>
                      ) : (
                        <>
                          <Lock className="w-4 h-4 mr-2" /> Lock
                        </>
                      )}
                    </Button>
                    {scheduledAt && (
                      <>
                        <Button
                          variant="ghost"
                          className="w-full justify-start"
                          onClick={() => {
                            onOpenSheet('');
                            onEditSchedule(card);
                          }}
                        >
                          <CalendarClock className="w-4 h-4 mr-2" /> Edit schedule
                        </Button>
                        <Button
                          variant="ghost"
                          className="w-full justify-start"
                          onClick={() => {
                            onOpenSheet('');
                            onCancelSchedule(card);
                          }}
                        >
                          <XCircle className="w-4 h-4 mr-2" /> Cancel scheduled send
                        </Button>
                      </>
                    )}
                    <Button
                      variant="ghost"
                      className="w-full justify-start text-red-600"
                      onClick={() => onDelete(card.externalId)}
                    >
                      Delete
                    </Button>
                  </motion.div>
                </SheetContent>
              </Sheet>
            </>
          ) : (
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button
                  size="icon"
                  className="bg-white text-black rounded-full shadow hover:bg-gray-100 p-2"
                >
                  <MoreHorizontal className="w-4 h-4" />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end">
                <DropdownMenuItem onClick={() => onEdit(card.externalId)}>
                  <Edit2 className="w-4 h-4 mr-2" /> Edit
                </DropdownMenuItem>
                <DropdownMenuItem onClick={() => onShare(card.externalId)}>
                  <Send className="w-4 h-4 mr-2" /> Share
                </DropdownMenuItem>
                <DropdownMenuItem onClick={() => onPreview(card.externalId)}>
                  <Eye className="w-4 h-4 mr-2" /> Preview
                </DropdownMenuItem>
                <DropdownMenuItem onClick={() => onQr(card.externalId)}>
                  <QrCode className="w-4 h-4 mr-2" /> Show QR Code
                </DropdownMenuItem>
                <DropdownMenuItem onClick={() => onToggleLock(card.externalId)}>
                  {card.locked ? (
                    <>
                      <Unlock className="w-4 h-4 mr-2" /> Unlock
                    </>
                  ) : (
                    <>
                      <Lock className="w-4 h-4 mr-2" /> Lock
                    </>
                  )}
                </DropdownMenuItem>
                {scheduledAt && (
                  <>
                    <DropdownMenuItem onClick={() => onEditSchedule(card)}>
                      <CalendarClock className="w-4 h-4 mr-2" /> Edit schedule
                    </DropdownMenuItem>
                    <DropdownMenuItem onClick={() => onCancelSchedule(card)}>
                      <XCircle className="w-4 h-4 mr-2" /> Cancel scheduled send
                    </DropdownMenuItem>
                  </>
                )}
                <DropdownMenuSeparator />
                <DropdownMenuItem
                  onClick={() => onDelete(card.externalId)}
                  className="text-red-600"
                >
                  Delete
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          )}
        </div>
      </CardContent>
    </Card>
  );
};

interface CardsListProps {
  cards: CardType[];
  onRefetch: () => void;
  onShareClick: (cardId: string) => void;
  onQrClick: (cardId: string) => void;
  // Supplied per card kind by the dashboard, so a new kind needs no changes here.
  createPath: string;
  createLabel: string;
  emptyTitle: string;
  emptyDescription: string;
  // Lets an org-owned card credit "you" instead of repeating your own name.
  currentUserId: string | null;
}

export const CardsList: React.FC<CardsListProps> = ({
  cards,
  onRefetch,
  onShareClick,
  onQrClick,
  createPath,
  createLabel,
  emptyTitle,
  emptyDescription,
  currentUserId,
}) => {
  const navigate = useNavigate();
  const [openSheetCardId, setOpenSheetCardId] = useState<string | null>(null);
  const [toggleLockCard] = useMutation(TOGGLE_LOCK_CARD);
  const [deliverCard] = useMutation(DELIVER_CARD);
  const [cancelScheduledDelivery] = useMutation(CANCEL_SCHEDULED_DELIVERY);

  // The card whose schedule is being edited, plus the picker's working state.
  const [editCard, setEditCard] = useState<CardType | null>(null);
  const [editDate, setEditDate] = useState<Date | undefined>(undefined);
  const [editTime, setEditTime] = useState('');
  const [editTimezone, setEditTimezone] = useState(() => detectTimezone());
  const [savingSchedule, setSavingSchedule] = useState(false);

  const handleToggleLockCard = async (cardId: string) => {
    try {
      await toggleLockCard({ variables: { input: { cardId } } });
      await onRefetch();
      toast.success('Card lock state updated.');
    } catch {
      toast.error('Failed to update lock state');
    }
  };

  const openScheduleEditor = (card: CardType) => {
    const timezone = detectTimezone();
    if (card.deliverAt) {
      const { date, time } = utcToZonedParts(card.deliverAt, timezone);
      setEditDate(date);
      setEditTime(time);
    }
    setEditTimezone(timezone);
    setEditCard(card);
  };

  const editDeliverAtIso =
    editDate && editTime
      ? zonedWallTimeToUtcISO(format(editDate, 'yyyy-MM-dd'), editTime, editTimezone)
      : null;
  const editInPast =
    editDeliverAtIso !== null && new Date(editDeliverAtIso).getTime() <= Date.now();

  const handleRescheduleSave = async () => {
    if (!editCard || !editCard.deliverToEmail || !editDeliverAtIso || editInPast) return;
    setSavingSchedule(true);
    try {
      const { data } = await deliverCard({
        variables: {
          input: {
            cardId: editCard.externalId,
            recipientEmail: editCard.deliverToEmail,
            deliverAt: editDeliverAtIso,
          },
        },
      });
      if (data.deliverCard.errors.length === 0) {
        toast.success(`Rescheduled for ${formatInTimezone(editDeliverAtIso, editTimezone)}`);
        setEditCard(null);
        await onRefetch();
      } else {
        toast.error(data.deliverCard.errors.join(', ') || 'Failed to reschedule');
      }
    } catch {
      toast.error('Failed to reschedule the send');
    } finally {
      setSavingSchedule(false);
    }
  };

  const handleCancelSchedule = async (card: CardType) => {
    try {
      const { data } = await cancelScheduledDelivery({
        variables: { input: { cardId: card.externalId } },
      });
      if (data.cancelScheduledDelivery.errors.length === 0) {
        toast.success('Scheduled send cancelled');
        await onRefetch();
      } else {
        toast.error(data.cancelScheduledDelivery.errors.join(', ') || 'Failed to cancel');
      }
    } catch {
      toast.error('Failed to cancel the scheduled send');
    }
  };

  if (cards.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-12 text-center space-y-6">
        <img src="/logo.svg" alt="CardJoy Logo" className="opacity-80 w-24 h-24" />
        <div className="space-y-2">
          <h2 className="text-2xl font-semibold text-gray-800">{emptyTitle}</h2>
          <p className="text-gray-500 text-lg">{emptyDescription}</p>
        </div>
        <motion.button
          onClick={() => navigate(createPath)}
          className="px-6 py-3 text-lg sm:text-xl font-extrabold bg-black text-white rounded-xl shadow-xl w-full sm:w-auto"
          whileHover={{ scale: 1.1 }}
          whileTap={{ scale: 0.9 }}
        >
          {createLabel}
        </motion.button>
      </div>
    );
  }

  return (
    <div className="w-full">
      <motion.button
        onClick={() => navigate(createPath)}
        className="mb-6 px-6 py-4 text-xl font-extrabold bg-black text-white rounded-xl shadow-xl w-full sm:w-auto"
        whileHover={{ scale: 1.1 }}
        whileTap={{ scale: 0.9 }}
      >
        {createLabel}
      </motion.button>
      <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4">
        {cards.map((card: CardType) => (
          <CardWithImageLoader
            key={card.externalId}
            card={card}
            creator={creatorLabel(card, currentUserId)}
            onEdit={id => navigate(`/card/${id}/edit`)}
            onShare={onShareClick}
            onPreview={id => window.open(`/card/${id}/viewable`, '_blank')}
            onQr={onQrClick}
            onToggleLock={handleToggleLockCard}
            onDelete={id => {
              // This will be handled by parent component
              window.dispatchEvent(new CustomEvent('deleteCard', { detail: { cardId: id } }));
            }}
            onEditSchedule={openScheduleEditor}
            onCancelSchedule={handleCancelSchedule}
            onOpenSheet={setOpenSheetCardId}
            openSheetCardId={openSheetCardId}
            navigate={navigate}
          />
        ))}
      </div>

      <Dialog open={!!editCard} onOpenChange={open => !open && setEditCard(null)}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Edit scheduled send</DialogTitle>
            <DialogDescription>
              {editCard?.deliverToEmail
                ? `Change when this card is sent to ${editCard.deliverToEmail}.`
                : 'Change when this card is sent.'}
            </DialogDescription>
          </DialogHeader>
          <SchedulePicker
            date={editDate}
            time={editTime}
            timezone={editTimezone}
            onDateChange={setEditDate}
            onTimeChange={setEditTime}
            onTimezoneChange={setEditTimezone}
            idPrefix="edit-schedule"
          />
          {editDeliverAtIso && (
            <p className={`text-sm ${editInPast ? 'text-red-600' : 'text-gray-600'}`}>
              {editInPast
                ? 'Pick a time in the future.'
                : `Sends ${formatInTimezone(editDeliverAtIso, editTimezone)}`}
            </p>
          )}
          <DialogFooter className="flex-col gap-2 sm:flex-row">
            <Button
              variant="outline"
              onClick={() => setEditCard(null)}
              className="w-full sm:w-auto"
            >
              Cancel
            </Button>
            <Button
              onClick={handleRescheduleSave}
              disabled={!editDeliverAtIso || editInPast || savingSchedule}
              className="w-full sm:w-auto"
            >
              {savingSchedule ? 'Saving…' : 'Save schedule'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
};
