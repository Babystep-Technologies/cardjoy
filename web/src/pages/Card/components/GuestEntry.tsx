// components/GuestEntry.tsx

import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { LogIn, User, ArrowRight } from 'lucide-react';

type Props = {
  onContinueAsGuest: (name: string) => void;
  redirectToLogin: string;
};

const GuestEntry: React.FC<Props> = ({ onContinueAsGuest, redirectToLogin }) => {
  const [guestName, setGuestName] = useState('');
  const [isGuestMode, setIsGuestMode] = useState(false);
  const navigate = useNavigate();

  return (
    <div className="min-h-screen flex items-center justify-center px-4">
      <Card className="w-full max-w-md min-h-[66vh] p-6 flex flex-col justify-between">
        <CardHeader className="text-center">
          <CardTitle className="text-2xl font-bold">Add a message to this card</CardTitle>
          {!isGuestMode && (
            <p className="text-gray-600 mt-2 text-base">{`Choose how you'd like to continue:`}</p>
          )}
        </CardHeader>

        <CardContent className="flex flex-col gap-4 flex-grow justify-center">
          {!isGuestMode ? (
            <>
              <Button
                className="w-full py-6 text-lg flex items-center justify-center gap-2"
                onClick={() => navigate(redirectToLogin)}
              >
                <LogIn className="w-5 h-5" />
                Log in to continue
              </Button>
              <Button
                variant="outline"
                className="w-full py-6 text-lg flex items-center justify-center gap-2"
                onClick={() => setIsGuestMode(true)}
              >
                <User className="w-5 h-5" />
                Continue as Guest
              </Button>
            </>
          ) : (
            <>
              <Input
                placeholder="Your name"
                value={guestName}
                onChange={e => setGuestName(e.target.value)}
                className="py-6 text-lg bg-white text-black placeholder:text-gray-400"
              />
              <Button
                className="w-full py-6 text-lg flex items-center justify-center gap-2"
                disabled={!guestName.trim()}
                onClick={() => onContinueAsGuest(guestName.trim())}
              >
                <ArrowRight className="w-5 h-5" />
                Start Writing
              </Button>
              <p className="text-sm text-gray-500 text-center mt-2">
                Prefer to log in?{' '}
                <button
                  onClick={() => navigate(redirectToLogin)}
                  className="text-blue-600 hover:underline"
                >
                  Sign in here
                </button>
              </p>
            </>
          )}
        </CardContent>
      </Card>
    </div>
  );
};

export default GuestEntry;
