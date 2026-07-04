import { useParams, useNavigate, useLocation } from 'react-router-dom';
import { gql, useQuery, useMutation } from '@apollo/client';
import CardMessage from '@/components/CardMessage';
import LoadingScreen from '@/components/Loading';
import ErrorScreen from '@/components/Error';
import { Message, Style } from '@/types/app';
import { SparklesText } from '@/components/magicui/sparkles-text';
import { Toaster, toast } from 'sonner';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { useState } from 'react';
import { ArrowLeft, ChevronLeft, ChevronRight } from 'lucide-react';

const GET_CARD_FOR_ADMIN = gql`
  query GetCardForAdmin($cardId: ID!, $showFlaggedMessages: Boolean!) {
    card(cardId: $cardId, showFlaggedMessages: $showFlaggedMessages) {
      title
      styles {
        name
        kind
        value
      }
      messages {
        id
        title
        text
        imageUrl
        flagged
        user {
          id
          name
        }
      }
      guestMessages {
        id
        title
        name
        text
        imageUrl
        flagged
      }
    }
  }
`;

const FLAG_CARD_MESSAGE = gql`
  mutation FlagCardMessage($input: FlagCardMessageInput!) {
    flagCardMessage(input: $input) {
      success
      errors
    }
  }
`;

const isUserMessage = (
  message: Message
): message is Message & { user: { id: string; name?: string } } => {
  return 'user' in message;
};

export default function AdminCard() {
  const { cardExternalId } = useParams();
  const navigate = useNavigate();
  const location = useLocation();
  const { data, loading, error, refetch } = useQuery(GET_CARD_FOR_ADMIN, {
    variables: { cardId: cardExternalId, showFlaggedMessages: true },
    fetchPolicy: 'network-only',
  });
  const [flagMessage] = useMutation(FLAG_CARD_MESSAGE);

  const [pendingFlagMessage, setPendingFlagMessage] = useState<Message | null>(null);

  // Extract navigation state for pagination
  const navigationState = location.state as {
    cardIds?: string[];
    currentIndex?: number;
  } | null;
  const cardIds = navigationState?.cardIds || [];
  const currentIndex = navigationState?.currentIndex ?? -1;
  const hasPrevCard = currentIndex > 0;
  const hasNextCard = currentIndex >= 0 && currentIndex < cardIds.length - 1;

  const cardData = data?.card;
  const allMessages = [...(cardData?.messages || []), ...(cardData?.guestMessages || [])];
  const coverStyle = cardData?.styles?.find((style: Style) => style.kind === 'cover');
  const backgroundColorStyle = cardData?.styles?.find(
    (style: Style) => style.kind === 'background_color'
  );
  const textColorStyle = cardData?.styles?.find((style: Style) => style.kind === 'text_color');

  const confirmFlag = async () => {
    if (!pendingFlagMessage) return;

    const message = pendingFlagMessage;
    const messageId = message.id;
    const messageKind = isUserMessage(message) ? 'user' : 'guest';
    const action = message.flagged ? 'unflag' : 'flag';

    try {
      const { data } = await flagMessage({ variables: { input: { messageId, messageKind } } });
      if (data.flagCardMessage.success) {
        toast.success(`Message ${action}ged successfully.`);
      } else {
        toast.error(data.flagCardMessage.errors.join(', ') || `Failed to ${action} message.`);
      }
      refetch();
    } catch (err) {
      toast.error('An unexpected error occurred while updating flag status.');
      console.error(err);
    } finally {
      setPendingFlagMessage(null);
    }
  };

  const navigateToCard = (index: number) => {
    if (index >= 0 && index < cardIds.length) {
      navigate(`/card/${cardIds[index]}`, {
        state: { cardIds, currentIndex: index },
      });
    }
  };

  const handlePrevCard = () => {
    if (hasPrevCard) {
      navigateToCard(currentIndex - 1);
    }
  };

  const handleNextCard = () => {
    if (hasNextCard) {
      navigateToCard(currentIndex + 1);
    }
  };

  if (loading) return <LoadingScreen />;
  if (error) return <ErrorScreen />;

  return (
    <div className="min-h-screen bg-gray-50">
      <Toaster position="top-center" />

      <Dialog open={!!pendingFlagMessage} onOpenChange={() => setPendingFlagMessage(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              Confirm {pendingFlagMessage?.flagged ? 'Unflag' : 'Flag'} Message
            </DialogTitle>
          </DialogHeader>
          <p className="text-sm text-gray-600">
            {pendingFlagMessage?.flagged
              ? 'This message will become visible to users again.'
              : 'Flagged messages will not be visible to external users. Are you sure you want to proceed?'}
          </p>
          <DialogFooter>
            <Button variant="ghost" onClick={() => setPendingFlagMessage(null)}>
              Cancel
            </Button>
            <Button variant="destructive" onClick={confirmFlag}>
              {pendingFlagMessage?.flagged ? 'Unflag' : 'Flag'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Header with back button and pagination */}
      <div className="bg-white shadow-sm border-b sticky top-0 z-10">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div className="flex items-center justify-between">
            <Button variant="ghost" onClick={() => navigate('/cards')} className="mb-2">
              <ArrowLeft className="w-4 h-4 mr-2" />
              Back to Cards
            </Button>
            {cardIds.length > 0 && (
              <div className="flex items-center gap-2">
                <Button size="sm" onClick={handlePrevCard} disabled={!hasPrevCard}>
                  <ChevronLeft className="w-4 h-4 mr-1" />
                  Previous
                </Button>
                <span className="text-sm text-gray-600">
                  {currentIndex + 1} of {cardIds.length}
                </span>
                <Button size="sm" onClick={handleNextCard} disabled={!hasNextCard}>
                  Next
                  <ChevronRight className="w-4 h-4 ml-1" />
                </Button>
              </div>
            )}
          </div>
        </div>
      </div>

      <div
        className="flex flex-col min-h-screen overflow-y-auto"
        style={{ backgroundColor: backgroundColorStyle?.value || '#fff' }}
      >
        {coverStyle && (
          <div className="w-full relative aspect-[4/1] max-h-[25vh] overflow-hidden">
            <img
              src={coverStyle.value}
              alt={coverStyle.name}
              className="absolute inset-0 w-full h-full object-cover"
            />
          </div>
        )}

        <div className="relative mb-10 mt-10 px-4 max-w-full">
          <SparklesText
            className="w-full text-center font-bold text-balance break-words text-wrap text-[clamp(1.75rem,5vw,2.75rem)]"
            style={{ color: textColorStyle?.value || 'black' }}
            text={cardData?.title}
          />
        </div>

        <div className="columns-1 sm:columns-2 lg:columns-3 gap-4 px-2 sm:px-6 space-y-4 pb-32">
          {allMessages.map((message, index: number) => (
            <div key={index} className="break-inside-avoid">
              <CardMessage
                message={message}
                showFlagAction
                onFlagToggle={() => setPendingFlagMessage(message)}
              />
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
