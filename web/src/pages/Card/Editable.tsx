import React, { useEffect, useState } from 'react';
import { useParams, Link, useSearchParams } from 'react-router-dom';
import { useQuery, gql, useMutation } from '@apollo/client';
import * as motion from 'motion/react-client';

import LoadingScreen from '@/components/Loading';
import ErrorScreen from '@/components/Error';
import CardMessage from './components/CardMessage';
import CardNotFound from './components/CardNotFound';
import EmptyCardState from './components/EmptyCardState';
import { Button } from '@/components/ui/button';
import { Lock, Send, Eye } from 'lucide-react';
import { ScrollProgress } from '@/components/magicui/scroll-progress';
import { SparklesText } from '@/components/magicui/sparkles-text';
import { UserMessageType, GuestMessageType, StyleType, JWTPayload } from '@/types/app';
import { useAuth } from '@/contexts/AuthContext';
import { getGuestMessageIdKey } from '@/lib/utils';
import { APP_TOKEN_KEY } from '@/lib/constants';
import { jwtDecode } from 'jwt-decode';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from '@/components/ui/dialog';
import { toast, Toaster } from 'sonner';
import ShareDialog from '@/components/ShareDialog';

const GET_CARD = gql`
  query Card($cardId: ID!, $showFlaggedMessages: Boolean!) {
    card(cardId: $cardId, showFlaggedMessages: $showFlaggedMessages) {
      title
      slug
      kind
      locked
      flagged
      messageLimitReached
      requireLoginToContribute
      contributorPrompt
      user {
        id
      }
      recipients
      coverImageUrl
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
        displayName
        flagged
        user {
          id
          name
        }
        reactedUserIds
        kind
      }
      guestMessages {
        id
        title
        name
        text
        imageUrl
        flagged
        reactedUserIds
        kind
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

const CardEditable: React.FC = () => {
  const { cardExternalId } = useParams<{ cardExternalId: string }>();
  const { user, setUser } = useAuth();
  const [searchParams, setSearchParams] = useSearchParams();
  const guestMessageIdKey = getGuestMessageIdKey(cardExternalId!);
  const guestMessageId = localStorage.getItem(guestMessageIdKey);
  const [pendingFlagMessage, setPendingFlagMessage] = useState<
    (UserMessageType | GuestMessageType) | null
  >(null);
  const [shareDialogOpen, setShareDialogOpen] = useState(false);

  // Accept auth token from URL (e.g. magic link from Slack)
  useEffect(() => {
    const token = searchParams.get('token');
    if (token) {
      try {
        const decoded = jwtDecode<JWTPayload>(token);
        if (decoded.exp * 1000 > Date.now()) {
          localStorage.setItem(APP_TOKEN_KEY, token);
          setUser(decoded);
        }
      } catch (e) {
        console.error('Invalid token in URL:', e);
      }
      // Remove token from URL to keep it clean
      searchParams.delete('token');
      setSearchParams(searchParams, { replace: true });
    }
  }, [searchParams, setSearchParams, setUser]);

  const { data, loading, error, refetch } = useQuery(GET_CARD, {
    variables: {
      cardId: cardExternalId,
      showFlaggedMessages: !!user,
    },
    fetchPolicy: 'network-only',
    nextFetchPolicy: 'network-only', // Also for subsequent fetches
  });

  const [flagMessage] = useMutation(FLAG_CARD_MESSAGE);

  const cardData = data?.card;
  const cardTitle = cardData?.title;
  const allMessages = [...(cardData?.messages || []), ...(cardData?.guestMessages || [])];

  const userMessage =
    user?.user_id &&
    cardData?.messages?.some(
      (msg: UserMessageType) => String(msg.user?.id) === String(user?.user_id)
    );
  const guestMessage = cardData?.guestMessages.find(
    (msg: GuestMessageType) => String(msg.id) === String(guestMessageId)
  );
  const backgroundColorStyle = cardData?.styles?.find(
    (style: StyleType) => style.kind === 'background_color'
  );
  const textColorStyle = cardData?.styles?.find((style: StyleType) => style.kind === 'text_color');
  const textColor = textColorStyle?.value || 'black';
  const contributorPrompt = cardData?.contributorPrompt?.trim();
  const recipientName = (cardData?.recipients || []).filter(Boolean).join(', ');

  const isOwner = user?.user_id && String(user.user_id) === String(cardData?.user?.id);
  const isContributor = !!userMessage || !!guestMessage;
  const isNewContributor = !isOwner && !isContributor;

  const handleShareClick = () => {
    setShareDialogOpen(true);
  };

  // Helper function to determine if a message is a user message
  const isUserMessage = (
    message: UserMessageType | GuestMessageType
  ): message is UserMessageType => {
    return 'user' in message;
  };

  // Show all messages to card owners (including flagged ones), filter flagged for non-owners
  const filteredMessages = isOwner ? allMessages : allMessages.filter(message => !message.flagged);

  const confirmFlag = async () => {
    if (!pendingFlagMessage) return;

    const message = pendingFlagMessage;
    const messageId = message.id;
    const messageKind = isUserMessage(message) ? 'user' : 'guest';
    const action = message.flagged ? 'unflag' : 'flag';

    try {
      const { data } = await flagMessage({
        variables: {
          input: {
            messageId,
            messageKind,
          },
        },
      });
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

  const shouldDisableButton =
    cardData?.locked || (cardData?.messageLimitReached && isNewContributor);

  let actionLabel = 'Add Message';
  if (isOwner) {
    actionLabel = 'Edit Card';
  } else if (isContributor) {
    actionLabel = 'Edit Message';
  }

  useEffect(() => {
    if (!cardTitle) return;
    document.title = `${cardTitle} | CardJoy`;
  }, [cardTitle]);

  if (loading) return <LoadingScreen />;
  if (error) return <ErrorScreen />;
  if (!cardData) return <CardNotFound />;

  if (cardData.flagged) {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center bg-[#fff6f6] px-4 text-center text-red-800">
        <h1 className="text-2xl sm:text-3xl font-semibold mb-4">
          This card is currently under review
        </h1>
        <p className="max-w-lg text-md sm:text-lg mb-6">
          This card has been temporarily hidden because it may violate our content policy. Our
          policy team is reviewing it to ensure it aligns with our community standards.
        </p>
        <Button onClick={() => {}} className="bg-red-600 hover:bg-red-700 text-white">
          Contact our team
        </Button>
      </div>
    );
  }

  const coverImageUrl = cardData?.coverImageUrl;

  return (
    <div
      className="min-h-screen flex flex-col pb-16"
      style={{ backgroundColor: backgroundColorStyle?.value || '#fff' }}
    >
      <Toaster position="top-center" />

      {/* Flag confirmation dialog */}
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
      {coverImageUrl && (
        <div className="w-full relative aspect-[4/3] max-h-[35vh] overflow-hidden">
          <img
            src={coverImageUrl}
            alt="Card Cover"
            className="absolute inset-0 w-full h-full object-cover"
          />
        </div>
      )}

      <ScrollProgress />

      {cardData.locked && (
        <div className="bg-yellow-100 text-yellow-800 flex items-center justify-center gap-2 py-3 px-4 rounded-md mx-4 sm:mx-auto max-w-2xl mt-6 mb-2 text-sm sm:text-base font-medium text-center">
          <Lock className="w-5 h-5" />
          This card is locked. No more messages can be added.
        </div>
      )}

      {cardData.messageLimitReached && isNewContributor && (
        <div className="bg-red-100 text-red-800 flex items-center justify-center gap-2 py-3 px-4 rounded-md mx-4 sm:mx-auto max-w-2xl mt-6 mb-2 text-sm sm:text-base font-medium text-center">
          This card has reached its message limit. You can still read what others wrote!
        </div>
      )}

      <div className="relative mb-6 mt-6 px-4 max-w-full">
        <SparklesText
          className="w-full text-center font-bold text-balance break-words text-wrap text-[clamp(1.75rem,5vw,2.75rem)]"
          style={{ color: textColor }}
          text={cardTitle}
        />
      </div>

      {/* Contributor context from the creator */}
      {contributorPrompt && (
        <div
          className="mb-8 max-w-2xl rounded-2xl border px-6 py-4 text-center backdrop-blur-sm mx-4 sm:mx-auto"
          style={{
            color: textColor,
            borderColor: `${textColor}26`,
            backgroundColor: `${textColor}0d`,
          }}
        >
          <p className="text-base sm:text-lg leading-relaxed whitespace-pre-line text-balance">
            {contributorPrompt}
          </p>
        </div>
      )}

      <div className="mb-6 px-4 sm:px-6 max-w-7xl mx-auto w-full">
        <div className="flex flex-col sm:flex-row gap-4 sm:gap-6">
          {shouldDisableButton ? (
            <Button
              variant="outline"
              disabled
              className="w-full sm:w-[200px] text-gray-500 bg-gray-100 cursor-not-allowed hover:bg-gray-100 px-8 py-6 text-lg font-semibold h-[64px]"
            >
              {actionLabel}
            </Button>
          ) : (
            <motion.div
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              className="w-full sm:w-[200px]"
            >
              {cardData?.requireLoginToContribute && !user && !isOwner ? (
                <a href={`/sign_in?redirect=/card/${cardExternalId}/edit`}>
                  <Button className="w-full px-8 py-6 text-lg font-extrabold h-[64px]">
                    {actionLabel}
                  </Button>
                </a>
              ) : (
                <Link to={`/card/${cardExternalId}/edit`}>
                  <Button className="w-full px-8 py-6 text-lg font-extrabold h-[64px]">
                    {actionLabel}
                  </Button>
                </Link>
              )}
            </motion.div>
          )}

          {/* View Card button */}
          <Link to={`/card/${cardExternalId}/viewable`} className="w-full sm:w-[200px]">
            <Button
              variant="outline"
              className="w-full px-8 py-6 text-lg font-semibold h-[64px] gap-2"
            >
              <Eye className="w-5 h-5" />
              View Card
            </Button>
          </Link>

          {/* Share button for card creator */}
          {isOwner && (
            <Button
              onClick={handleShareClick}
              className="w-full sm:w-[200px] px-8 py-6 text-lg font-extrabold h-[64px] bg-blue-600 hover:bg-blue-700 text-white"
            >
              <Send className="w-5 h-5 mr-2" />
              Share Card
            </Button>
          )}
        </div>
      </div>

      {filteredMessages.length === 0 ? (
        <div className="py-10">
          <EmptyCardState
            recipientName={recipientName}
            isCreator={!!isOwner}
            textColor={textColor}
          />
        </div>
      ) : (
        <div className="columns-1 sm:columns-2 md:columns-3 gap-4 px-4 sm:px-6 max-w-7xl mx-auto w-full">
          {filteredMessages.map((message, index) => (
            <div key={index} className="break-inside-avoid w-full">
              <CardMessage
                message={message}
                showFlagAction={!!isOwner}
                onFlagToggle={() => setPendingFlagMessage(message)}
              />
            </div>
          ))}
        </div>
      )}

      {/* Share Dialog */}
      <ShareDialog
        open={shareDialogOpen}
        onOpenChange={setShareDialogOpen}
        cardId={cardExternalId || ''}
        slug={data?.card?.slug}
        type="card"
        isOneOnOne={cardData?.kind === 'one_on_one'}
      />
    </div>
  );
};

export default CardEditable;
