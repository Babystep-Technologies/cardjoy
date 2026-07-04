import React from 'react';
import { Card, CardHeader, CardTitle, CardContent, CardFooter } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Flag, ShieldCheck } from 'lucide-react';
import { Message, UserMessage } from '@/types/app';

type Props = {
  message: Message;
  showFlagAction?: boolean;
  onFlagToggle?: (message: Message) => void;
};

const isUserMessage = (msg: Message): msg is UserMessage => {
  return 'user' in msg;
};

const CardMessage: React.FC<Props> = ({ message, showFlagAction = false, onFlagToggle }) => {
  const handleFlagClick = () => {
    if (onFlagToggle) {
      onFlagToggle(message);
    }
  };

  return (
    <Card className="relative group w-full bg-white shadow-md rounded-lg mb-4 pt-0 flex flex-col overflow-hidden">
      {/* Flagged message overlay */}
      {message.flagged && (
        <div className="absolute inset-0 z-20 bg-black/40 group-hover:bg-transparent transition-colors duration-300 backdrop-blur-sm group-hover:backdrop-blur-none flex items-center justify-center text-white group-hover:text-transparent font-semibold text-xs sm:text-sm uppercase tracking-wide text-center px-4 pointer-events-none">
          This message is hidden from users. Hover to preview.
        </div>
      )}

      {message.imageUrl && (
        <img
          src={message.imageUrl}
          alt={`Image for message ${message.id}`}
          className="w-full max-h-[400px] object-cover rounded-t-lg"
        />
      )}

      {/* Flag action button */}
      {showFlagAction && (
        <Button
          variant="ghost"
          size="sm"
          onClick={handleFlagClick}
          className="absolute top-2 right-2 z-30 bg-white hover:bg-gray-100 text-sm flex items-center gap-1"
        >
          {message.flagged ? (
            <>
              <ShieldCheck className="w-4 h-4 text-green-600" />
              Unflag
            </>
          ) : (
            <>
              <Flag className="w-4 h-4 text-red-600" />
              Flag
            </>
          )}
        </Button>
      )}

      <div className="flex flex-col p-4 overflow-visible z-10">
        <CardHeader className="p-0">
          <CardTitle className="text-xl font-bold text-left break-words">{message.title}</CardTitle>
        </CardHeader>
        <CardContent className="p-0">
          <p className="text-left text-lg whitespace-pre-line break-words">{message.text}</p>
        </CardContent>
        <CardFooter className="mt-2 p-2 text-right text-base text-gray-500">
          {isUserMessage(message)
            ? message.user?.name && `— ${message.user.name}`
            : message.name && `— ${message.name}`}
        </CardFooter>
      </div>
    </Card>
  );
};

export default CardMessage;
