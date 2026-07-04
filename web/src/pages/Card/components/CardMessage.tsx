import React, { useState } from 'react';
import { gql, useMutation } from '@apollo/client';
import { useLocation } from 'react-router-dom';
import { Card, CardHeader, CardTitle, CardContent, CardFooter } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Flag, ShieldCheck, Eye, EyeOff } from 'lucide-react';
import burstUrl from '@/assets/burst.svg';
import confetti from 'canvas-confetti';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter as UIDialogFooter,
} from '@/components/ui/dialog';
import { useAuth } from '@/contexts/AuthContext';

type Message = {
  id: string;
  title: string;
  text: string;
  imageUrl?: string | null;
  user?: { id?: string; name?: string } | null;
  name?: string | null;
  displayName?: string;
  flagged?: boolean;
  reactedUserIds: string[];
  kind: string;
};

type Props = {
  message: Message;
  showFlagAction?: boolean;
  onFlagToggle?: (message: Message) => void;
  isCardOwner?: boolean;
  glassmorphism?: boolean;
};

const REACT_TO_MESSAGE = gql`
  mutation ReactToMessage($input: ReactToMessageInput!) {
    reactToMessage(input: $input) {
      success
      errors
    }
  }
`;

const CardMessage: React.FC<Props> = ({
  message,
  showFlagAction = false,
  onFlagToggle,
  glassmorphism = false,
}) => {
  const { user } = useAuth();
  const userId: string | undefined =
    typeof user?.user_id === 'number' ? String(user.user_id) : undefined;
  const location = useLocation();
  const [reactedUserIds, setReactedUserIds] = useState<string[]>(message.reactedUserIds || []);
  const [showLoginDialog, setShowLoginDialog] = useState(false);
  const [isOverlayHidden, setIsOverlayHidden] = useState(false);
  const reacted = !!userId && reactedUserIds.includes(userId);
  const [reactToMessage] = useMutation(REACT_TO_MESSAGE);

  const handleFlagClick = () => {
    if (onFlagToggle) {
      onFlagToggle(message);
    }
  };

  const handleOverlayClick = () => {
    setIsOverlayHidden(!isOverlayHidden);
  };

  const handleReactionClick = async (event: React.MouseEvent<HTMLButtonElement>) => {
    if (userId === undefined) {
      setShowLoginDialog(true);
      return;
    }

    if (!reacted) {
      const rect = event.currentTarget.getBoundingClientRect();
      confetti({
        particleCount: 80,
        spread: 70,
        origin: {
          x: rect.left / window.innerWidth,
          y: rect.top / window.innerHeight,
        },
      });
    }

    const newReactions = reacted
      ? reactedUserIds.filter(id => id !== userId)
      : [...reactedUserIds, userId];
    setReactedUserIds(newReactions);

    try {
      await reactToMessage({
        variables: { input: { messageId: message.id, messageType: message.kind } },
      });
    } catch (err) {
      console.error('Failed to react to message:', err);
      setReactedUserIds(reactedUserIds);
    }
  };

  return (
    <>
      <div className="relative">
        {/* Action buttons row - outside of Card */}
        {(showFlagAction || (message.flagged && showFlagAction)) && (
          <div className="flex justify-between items-center p-2 bg-gray-100 border border-gray-200 rounded-t-lg mb-0">
            <div className="flex gap-2">
              {/* Mobile toggle button for flagged messages */}
              {message.flagged && showFlagAction && (
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={handleOverlayClick}
                  className="bg-white hover:bg-gray-200 text-xs flex items-center gap-1 md:hidden"
                >
                  {isOverlayHidden ? (
                    <>
                      <EyeOff className="w-3 h-3" />
                      Hide
                    </>
                  ) : (
                    <>
                      <Eye className="w-3 h-3" />
                      Show
                    </>
                  )}
                </Button>
              )}
            </div>

            <div className="flex gap-2">
              {/* Flag action button */}
              {showFlagAction && (
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={handleFlagClick}
                  className="bg-white hover:bg-gray-200 text-xs flex items-center gap-1"
                >
                  {message.flagged ? (
                    <>
                      <ShieldCheck className="w-3 h-3 text-green-600" />
                      Unflag
                    </>
                  ) : (
                    <>
                      <Flag className="w-3 h-3 text-red-600" />
                      Flag
                    </>
                  )}
                </Button>
              )}
            </div>
          </div>
        )}

        <Card
          className={`relative group w-full ${glassmorphism ? 'bg-white/90 backdrop-blur-sm' : 'bg-white'} shadow-md mb-4 pt-0 flex flex-col justify-between overflow-hidden ${showFlagAction || (message.flagged && showFlagAction) ? 'rounded-t-none rounded-b-lg' : 'rounded-lg'}`}
        >
          {/* Flagged message overlay */}
          {message.flagged && !isOverlayHidden && (
            <div
              className="absolute inset-0 z-20 bg-black/40 hover:bg-transparent transition-colors duration-300 backdrop-blur-sm hover:backdrop-blur-none flex items-center justify-center text-white hover:text-transparent font-semibold text-xs sm:text-sm uppercase tracking-wide text-center px-4 cursor-pointer select-none"
              onClick={handleOverlayClick}
            >
              <span className="pointer-events-none">
                This message is hidden from users.
                <br className="hidden sm:inline" />
                <span className="hidden md:inline"> Hover to preview.</span>
                <span className="md:hidden"> Tap to preview.</span>
              </span>
            </div>
          )}

          {/* Image at the very top */}
          {message.imageUrl && (
            <img
              src={message.imageUrl}
              alt={`Image for message ${message.id}`}
              className="w-full object-cover"
            />
          )}

          <div className="flex flex-col px-4 pt-4 pb-2 grow z-10">
            <CardHeader className="p-0">
              <CardTitle className="text-xl font-bold text-left break-words">
                {message.title}
              </CardTitle>
            </CardHeader>

            <CardContent className="p-0 mt-2 grow">
              <p className="text-left text-lg whitespace-pre-line break-words">{message.text}</p>
            </CardContent>

            <CardFooter className="mt-4 p-0 pt-4 flex items-center justify-between text-base text-gray-500">
              <span>
                {'user' in message
                  ? message.displayName || message.user?.name
                    ? `— ${message.displayName || message.user?.name}`
                    : ''
                  : message.name && `— ${message.name}`}
              </span>

              <button
                onClick={handleReactionClick}
                className="flex items-center gap-1 text-sm text-gray-500 hover:text-black transition-colors"
              >
                <img
                  src={burstUrl}
                  alt="React"
                  className={`w-5 h-5 pr-1 ${reacted ? 'opacity-100' : 'opacity-40'} transition-opacity`}
                />
                <span className={`mr-1 ${reacted ? 'text-black' : 'text-gray-400'}`}>
                  {reactedUserIds.length}
                </span>
              </button>
            </CardFooter>
          </div>
        </Card>
      </div>

      <Dialog open={showLoginDialog} onOpenChange={setShowLoginDialog}>
        <DialogContent className="max-w-sm text-center">
          <div className="flex flex-col items-center space-y-2">
            <DialogHeader className="text-center">
              <DialogTitle className="text-lg font-semibold">Please log in to react</DialogTitle>
            </DialogHeader>
            <p className="text-gray-600">You'll be redirected back after login.</p>
          </div>

          <UIDialogFooter className="flex justify-center gap-4 pt-4">
            <Button variant="ghost" onClick={() => setShowLoginDialog(false)}>
              Cancel
            </Button>
            <Button asChild>
              <a href={`/sign_in?redirect=${location.pathname}`}>Log In</a>
            </Button>
          </UIDialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
};

export default CardMessage;
