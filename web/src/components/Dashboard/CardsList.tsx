import React, { useState } from 'react';
import { useMutation } from '@apollo/client';
import { useNavigate } from 'react-router-dom';
import { gql } from '@apollo/client';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { Sheet, SheetContent, SheetHeader, SheetTitle } from '@/components/ui/sheet';
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
} from '@/components/ui/dropdown-menu';
import { MoreHorizontal, Lock, Edit2, Eye, Send, Unlock, QrCode, RotateCcw } from 'lucide-react';
import * as motion from 'motion/react-client';
import { isMobile } from '@/lib/utils';
import { CardType } from '@/types/app';
import { toast } from 'sonner';

const TOGGLE_LOCK_CARD = gql`
  mutation ToggleLockCard($input: ToggleLockCardInput!) {
    toggleLockCard(input: $input) {
      success
    }
  }
`;

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
const CardWithImageLoader: React.FC<{
  card: CardType;
  onEdit: (id: string) => void;
  onShare: (id: string) => void;
  onPreview: (id: string) => void;
  onQr: (id: string) => void;
  onToggleLock: (id: string) => void;
  onDelete: (id: string) => void;
  onOpenSheet: (id: string) => void;
  openSheetCardId: string | null;
  navigate: (path: string) => void;
}> = ({
  card,
  onEdit,
  onShare,
  onPreview,
  onQr,
  onToggleLock,
  onDelete,
  onOpenSheet,
  openSheetCardId,
  navigate,
}) => {
  const { loading, error, retry } = useImageLoader(card.coverImageUrl || null);

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

        <div className="bg-white/90 text-black text-center px-4 py-3 rounded-md shadow-md mx-auto w-[80%] max-w-[90%] overflow-hidden">
          <h2 className="font-bold text-lg truncate">{card.title}</h2>
          {card.recipients?.length > 0 && (
            <p className="text-sm font-medium mt-1 truncate">For: {card.recipients.join(', ')}</p>
          )}
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
}) => {
  const navigate = useNavigate();
  const [openSheetCardId, setOpenSheetCardId] = useState<string | null>(null);
  const [toggleLockCard] = useMutation(TOGGLE_LOCK_CARD);

  const handleToggleLockCard = async (cardId: string) => {
    try {
      await toggleLockCard({ variables: { input: { cardId } } });
      await onRefetch();
      toast.success('Card lock state updated.');
    } catch {
      toast.error('Failed to update lock state');
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
            onEdit={id => navigate(`/card/${id}/edit`)}
            onShare={onShareClick}
            onPreview={id => window.open(`/card/${id}/viewable`, '_blank')}
            onQr={onQrClick}
            onToggleLock={handleToggleLockCard}
            onDelete={id => {
              // This will be handled by parent component
              window.dispatchEvent(new CustomEvent('deleteCard', { detail: { cardId: id } }));
            }}
            onOpenSheet={setOpenSheetCardId}
            openSheetCardId={openSheetCardId}
            navigate={navigate}
          />
        ))}
      </div>
    </div>
  );
};
