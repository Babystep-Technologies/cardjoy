import React from 'react';
import { useNavigate } from 'react-router-dom';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { LogIn, User } from 'lucide-react';

interface RSVPGuestEntryProps {
  invitationId: string;
  onContinueAsGuest: () => void;
}

const RSVPGuestEntry: React.FC<RSVPGuestEntryProps> = ({ invitationId, onContinueAsGuest }) => {
  const navigate = useNavigate();

  const handleLogin = () => {
    // Redirect to login with return URL to come back to this invitation
    const returnUrl = `/invitation/${invitationId}`;
    navigate(`/sign_in?redirect=${encodeURIComponent(returnUrl)}`);
  };

  return (
    <Card className="p-6 space-y-6 bg-white/95 backdrop-blur border-2">
      <div className="text-center">
        <h3 className="text-2xl font-bold mb-2">Will you be there?</h3>
        <p className="text-gray-600">Choose how you'd like to RSVP:</p>
      </div>

      <div className="space-y-3">
        <Button
          onClick={handleLogin}
          className="w-full py-6 text-lg flex items-center justify-center gap-2 bg-gradient-to-r from-purple-600 to-pink-600 hover:from-purple-700 hover:to-pink-700"
        >
          <LogIn className="w-5 h-5" />
          Log in to RSVP
        </Button>

        <Button
          variant="outline"
          onClick={onContinueAsGuest}
          className="w-full py-6 text-lg flex items-center justify-center gap-2 border-2"
        >
          <User className="w-5 h-5" />
          RSVP as Guest
        </Button>
      </div>
    </Card>
  );
};

export default RSVPGuestEntry;
