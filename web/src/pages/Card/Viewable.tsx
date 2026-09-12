import React, { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import { gql, useQuery } from '@apollo/client';

import LoadingScreen from '@/components/Loading';
import ErrorScreen from '@/components/Error';
import CardMessage from './components/CardMessage';
import CardNotFound from './components/CardNotFound';
import EmptyCardState from './components/EmptyCardState';
import OneOnOneCardView from './components/OneOnOneCardView';
import { ScrollProgress } from '@/components/magicui/scroll-progress';
import { SparklesText } from '@/components/magicui/sparkles-text';
import { Button } from '@/components/ui/button';
import { StyleType } from '@/types/app';
import { useAuth } from '@/contexts/AuthContext';
import { Toaster } from 'sonner';
import { Send, ArrowLeft, Settings, Pencil } from 'lucide-react';
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

const CardViewable: React.FC = () => {
  const { user } = useAuth();
  const { cardExternalId } = useParams<{ cardExternalId: string }>();
  const [shareDialogOpen, setShareDialogOpen] = useState(false);

  const { data, loading, error } = useQuery(GET_CARD, {
    variables: {
      cardId: cardExternalId,
      showFlaggedMessages: false,
    },
    fetchPolicy: 'network-only',
    nextFetchPolicy: 'network-only',
  });

  const cardData = data?.card;
  const cardTitle = cardData?.title;
  const allMessages = [...(cardData?.messages || []), ...(cardData?.guestMessages || [])];
  const visibleMessages = allMessages.filter(m => !m.flagged);
  const isCardCreator =
    user?.user_id && cardData?.user?.id && String(user.user_id) === String(cardData.user.id);

  const backgroundColorStyle = cardData?.styles?.find(
    (style: StyleType) => style.kind === 'background_color'
  );
  const textColorStyle = cardData?.styles?.find((style: StyleType) => style.kind === 'text_color');
  const textColor = textColorStyle?.value || '#1a1a1a';
  const coverImageUrl = cardData?.coverImageUrl;
  const contributorPrompt = cardData?.contributorPrompt?.trim();
  const recipientName = (cardData?.recipients || []).filter(Boolean).join(', ');
  const hasMessages = visibleMessages.length > 0;
  // A logged-out visitor must sign in first when the creator requires it to contribute.
  const requiresLoginToContribute = cardData?.requireLoginToContribute && !user && !isCardCreator;

  const handleShareClick = () => {
    setShareDialogOpen(true);
  };

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

  // A 1-on-1 card gets its own single-message reveal, not the group scroll story.
  if (cardData.kind === 'one_on_one') {
    return (
      <>
        <Toaster />
        <OneOnOneCardView
          card={cardData}
          externalId={cardExternalId || ''}
          isCreator={!!isCardCreator}
          onShareClick={handleShareClick}
        />
        <ShareDialog
          open={shareDialogOpen}
          onOpenChange={setShareDialogOpen}
          cardId={cardExternalId || ''}
          slug={data?.card?.slug}
          type="card"
          isOneOnOne
        />
      </>
    );
  }

  return (
    <div className="relative" style={{ backgroundColor: backgroundColorStyle?.value || '#fff' }}>
      <Toaster />

      <ScrollProgress />

      {/* Creator Navigation Bar */}
      {isCardCreator && (
        <div className="fixed top-0 left-0 right-0 z-50 bg-white/95 backdrop-blur border-b shadow-sm">
          <div className="max-w-7xl mx-auto px-4 h-14 flex items-center justify-between">
            <Link
              to="/"
              className="flex items-center gap-2 text-gray-600 hover:text-gray-900 transition-colors"
            >
              <ArrowLeft className="w-4 h-4" />
              <span className="font-medium">Dashboard</span>
            </Link>
            <div className="flex items-center gap-3">
              <span className="text-sm text-gray-500">Viewing as creator</span>
              <Link to={`/card/${cardExternalId}/edit`}>
                <Button variant="outline" size="sm" className="gap-2">
                  <Settings className="w-4 h-4" />
                  Edit
                </Button>
              </Link>
            </div>
          </div>
        </div>
      )}

      {/* ===== HERO SECTION ===== */}
      <div
        className={`relative flex flex-col items-center justify-center min-h-screen px-4 ${isCardCreator ? 'pt-14' : ''}`}
      >
        {/* Cover image as hero background */}
        {coverImageUrl && (
          <div className="absolute inset-0 z-0">
            <img src={coverImageUrl} alt="Card Cover" className="w-full h-full object-cover" />
            <div
              className="absolute inset-0"
              style={{
                background: `linear-gradient(to bottom, ${backgroundColorStyle?.value || '#fff'}40 0%, ${backgroundColorStyle?.value || '#fff'}cc 60%, ${backgroundColorStyle?.value || '#fff'} 100%)`,
              }}
            />
          </div>
        )}

        <div className="relative z-[1] text-center">
          <SparklesText
            className="w-full text-center font-bold text-balance break-words text-wrap text-[clamp(2rem,6vw,3.5rem)]"
            style={{ color: textColor }}
            colors={{
              first: 'var(--color-brand-pink)',
              second: 'var(--color-brand-blue)',
            }}
            text={cardTitle}
          />

          {/* Contributor context from the creator */}
          {contributorPrompt && (
            <div
              className="mx-auto mt-6 max-w-xl rounded-2xl border px-6 py-4 backdrop-blur-sm"
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

          {/* Creator actions */}
          {isCardCreator && (
            <div className="mt-10 flex flex-col sm:flex-row gap-4 justify-center">
              <Link to={`/card/${cardExternalId}/editable`}>
                <Button
                  variant="outline"
                  className="px-8 py-6 text-lg font-semibold h-[64px] gap-2"
                >
                  <Pencil className="w-5 h-5" />
                  Edit Card
                </Button>
              </Link>
              <Button
                onClick={handleShareClick}
                className="px-8 py-6 text-lg font-extrabold h-[64px] bg-blue-600 hover:bg-blue-700 text-white"
              >
                <Send className="w-5 h-5 mr-2" />
                Share Card
              </Button>
            </div>
          )}

          {/* Friendly empty state so a card with no messages never looks blank */}
          {!hasMessages && (
            <div className="mt-12">
              <EmptyCardState
                recipientName={recipientName}
                textColor={textColor}
                cta={
                  requiresLoginToContribute ? (
                    <a href={`/sign_in?redirect=/card/${cardExternalId}/edit`}>
                      <Button className="px-8 py-6 text-lg font-extrabold h-[64px]">
                        Add Message
                      </Button>
                    </a>
                  ) : (
                    <Link to={`/card/${cardExternalId}/edit`}>
                      <Button className="px-8 py-6 text-lg font-extrabold h-[64px]">
                        Add Message
                      </Button>
                    </Link>
                  )
                }
              />
            </div>
          )}
        </div>
      </div>

      {/* ===== MESSAGE GRID ===== */}
      {hasMessages && (
        <div className="pb-16 px-4 sm:px-6 max-w-7xl mx-auto w-full">
          <div className="columns-1 sm:columns-2 md:columns-3 gap-4">
            {visibleMessages.map((message, index) => (
              <div key={message.id || index} className="break-inside-avoid w-full">
                <CardMessage message={message} />
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Share Dialog */}
      <ShareDialog
        open={shareDialogOpen}
        onOpenChange={setShareDialogOpen}
        cardId={cardExternalId || ''}
        slug={data?.card?.slug}
        type="card"
      />
    </div>
  );
};

export default CardViewable;
