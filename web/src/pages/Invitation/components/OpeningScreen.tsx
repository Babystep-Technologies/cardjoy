import React from 'react';
import { Button } from '@/components/ui/button';
import { Mail } from 'lucide-react';

interface OpeningScreenProps {
  message?: string | null;
  onOpen: () => void;
}

const OpeningScreen: React.FC<OpeningScreenProps> = ({ message, onOpen }) => {
  const displayMessage = message || "You're invited to something special";

  return (
    <div className="fixed inset-0 flex flex-col items-center justify-center bg-gradient-to-br from-yellow-50 via-pink-50 to-blue-50">
      <div className="text-center px-8 max-w-md">
        <div className="mb-8">
          <div className="inline-flex items-center justify-center w-24 h-24 rounded-full bg-gradient-to-br from-purple-400 via-pink-400 to-blue-400 shadow-2xl">
            <Mail className="w-12 h-12 text-white" />
          </div>
        </div>

        <p className="text-2xl sm:text-3xl font-semibold text-gray-800 mb-12 leading-relaxed">
          {displayMessage}
        </p>

        <Button
          onClick={onOpen}
          size="lg"
          className="bg-gradient-to-r from-purple-500 via-pink-500 to-blue-500 hover:from-purple-600 hover:via-pink-600 hover:to-blue-600 text-white text-lg px-10 py-6 rounded-full shadow-xl transition-all duration-300 hover:scale-105 hover:shadow-2xl"
        >
          Open Invitation
        </Button>
      </div>
    </div>
  );
};

export default OpeningScreen;
