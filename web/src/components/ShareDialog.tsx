import React, { useState } from 'react';
import { gql, useMutation, ApolloError } from '@apollo/client';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import MultiEmailInput from '@/components/MultipleEmailInput';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { toast } from 'sonner';
import { Check } from 'lucide-react';

// Social media icons as simple SVG components
const WhatsAppIcon = () => (
  <svg viewBox="0 0 24 24" className="w-5 h-5" fill="currentColor">
    <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z" />
  </svg>
);

const FacebookIcon = () => (
  <svg viewBox="0 0 24 24" className="w-5 h-5" fill="currentColor">
    <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z" />
  </svg>
);

const TwitterIcon = () => (
  <svg viewBox="0 0 24 24" className="w-5 h-5" fill="currentColor">
    <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
  </svg>
);

const INVITE_TO_CARD = gql`
  mutation InviteToCard($input: InviteToCardInput!) {
    inviteToCard(input: $input) {
      success
    }
  }
`;

interface ShareDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  cardId: string;
  slug?: string | null;
  type?: 'card' | 'invitation';
  /** 1-on-1 cards have no group-contribution flow, so they share via a single link only. */
  isOneOnOne?: boolean;
}

const ShareDialog: React.FC<ShareDialogProps> = ({
  open,
  onOpenChange,
  cardId,
  slug,
  type = 'card',
  isOneOnOne = false,
}) => {
  const [collaboratorEmails, setCollaboratorEmails] = useState<string[]>([]);
  const [viewerEmails, setViewerEmails] = useState<string[]>([]);
  const [sending, setSending] = useState(false);
  const [copiedEditable, setCopiedEditable] = useState(false);
  const [copiedViewable, setCopiedViewable] = useState(false);

  const [sendInvite] = useMutation(INVITE_TO_CARD);

  // Use slug if available, otherwise use cardId
  const identifier = slug || cardId;
  const isInvitation = type === 'invitation';
  // Invitations and 1-on-1 cards share via a single link, with no "invite others to write" tab.
  const simpleShare = isInvitation || isOneOnOne;

  // Generate URLs based on type
  const getEditableUrl = () => {
    if (isInvitation) {
      return `${import.meta.env.VITE_PREVIEW_ENDPOINT}/invitation/${identifier}`;
    }
    return `${import.meta.env.VITE_PREVIEW_ENDPOINT}/card/${identifier}/editable`;
  };

  const getViewableUrl = () => {
    if (isInvitation) {
      return `${import.meta.env.VITE_PREVIEW_ENDPOINT}/invitation/${identifier}`;
    }
    return `${import.meta.env.VITE_PREVIEW_ENDPOINT}/card/${identifier}/viewable`;
  };

  const handleInvite = async (emails: string[], kind: 'collaborate' | 'view') => {
    if (!cardId || emails.length === 0) return;
    setSending(true);
    try {
      await sendInvite({
        variables: { input: { cardId, emails, kind } },
      });
      toast.success(`Invitations sent for ${kind === 'collaborate' ? 'collaborators' : 'viewers'}`);
    } catch (error) {
      const err = error as ApolloError;
      toast.error(`Failed to send invites: ${err.message}`);
    } finally {
      setSending(false);
    }
  };

  const handleCopyEditable = () => {
    navigator.clipboard.writeText(getEditableUrl());
    setCopiedEditable(true);
    setTimeout(() => setCopiedEditable(false), 2000);
  };

  const handleCopyViewable = () => {
    navigator.clipboard.writeText(getViewableUrl());
    setCopiedViewable(true);
    setTimeout(() => setCopiedViewable(false), 2000);
  };

  const getShareText = () => {
    return isInvitation ? "You're invited! Check out this invitation" : 'Check out this card';
  };

  const shareViaWhatsApp = (url: string) => {
    const text = encodeURIComponent(`${getShareText()}: ${url}`);
    window.open(`https://wa.me/?text=${text}`, '_blank');
  };

  const shareViaFacebook = (url: string) => {
    window.open(
      `https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(url)}`,
      '_blank'
    );
  };

  const shareViaTwitter = (url: string) => {
    const text = encodeURIComponent(getShareText());
    window.open(
      `https://twitter.com/intent/tweet?url=${encodeURIComponent(url)}&text=${text}`,
      '_blank'
    );
  };

  const SocialShareButtons = ({ url }: { url: string }) => (
    <div className="flex items-center gap-2 mt-3">
      <span className="text-sm text-gray-600">Share via:</span>
      <Button
        variant="outline"
        size="icon"
        className="h-9 w-9 text-green-600 hover:text-green-700 hover:bg-green-50"
        onClick={() => shareViaWhatsApp(url)}
        title="Share via WhatsApp"
      >
        <WhatsAppIcon />
      </Button>
      <Button
        variant="outline"
        size="icon"
        className="h-9 w-9 text-blue-600 hover:text-blue-700 hover:bg-blue-50"
        onClick={() => shareViaFacebook(url)}
        title="Share via Facebook"
      >
        <FacebookIcon />
      </Button>
      <Button
        variant="outline"
        size="icon"
        className="h-9 w-9 text-black hover:bg-gray-100"
        onClick={() => shareViaTwitter(url)}
        title="Share via X (Twitter)"
      >
        <TwitterIcon />
      </Button>
    </div>
  );

  // Reset state when dialog closes
  React.useEffect(() => {
    if (!open) {
      setCollaboratorEmails([]);
      setViewerEmails([]);
      setSending(false);
      setCopiedEditable(false);
      setCopiedViewable(false);
    }
  }, [open]);

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="bg-[#f9f9f6] text-black rounded-xl shadow-xl max-w-lg w-full p-6">
        <DialogHeader>
          <DialogTitle>Share This {isInvitation ? 'Invitation' : 'Card'}</DialogTitle>
        </DialogHeader>

        {simpleShare ? (
          // Simple share interface for invitations and 1-on-1 cards (no tabs)
          <div className="mt-4">
            <p className="text-sm text-gray-600 mb-2">
              {isInvitation
                ? 'Share this invitation with your guests.'
                : 'Send this card to the recipient.'}
            </p>
            <div className="text-sm text-gray-700 mt-2 font-medium">
              Share this link via text, email, Slack, or WhatsApp, etc.
            </div>
            <p className="text-xs text-gray-500 mb-1">
              {isInvitation
                ? 'Anyone with the link can access the invitation.'
                : 'Anyone with the link can view the card.'}
            </p>
            <div className="flex items-center mt-2 gap-2">
              <Input readOnly value={getViewableUrl()} />
              <Button variant="outline" onClick={handleCopyViewable}>
                <span className="inline-flex justify-center w-[48px]">
                  {copiedViewable ? <Check className="w-4 h-4 text-green-600" /> : 'Copy'}
                </span>
              </Button>
            </div>
            <SocialShareButtons url={getViewableUrl()} />
          </div>
        ) : (
          // Tabs interface for group cards only
          <Tabs defaultValue="collaborate" className="mt-4">
            <TabsList className="mb-4 flex gap-2 bg-transparent">
              <TabsTrigger value="collaborate" className="text-black data-[state=active]:bg-white">
                Invite others to write
              </TabsTrigger>
              <TabsTrigger value="view" className="text-black data-[state=active]:bg-white">
                Send to receivers
              </TabsTrigger>
            </TabsList>

            <TabsContent value="collaborate">
              <p className="text-sm text-gray-600 mb-2">
                Invite others to contribute messages to this card.
              </p>
              <MultiEmailInput value={collaboratorEmails} onChange={setCollaboratorEmails} />
              <Button
                disabled={sending || collaboratorEmails.length === 0}
                onClick={() => handleInvite(collaboratorEmails, 'collaborate')}
                className="mb-4"
              >
                {sending ? 'Sending...' : 'Send Invite'}
              </Button>
              <div className="text-sm text-gray-700 mt-2 font-medium">
                Or share this link via text, Slack, or WhatsApp, etc.
              </div>
              <p className="text-xs text-gray-500 mb-1">
                Anyone with the link can access the card.
              </p>
              <div className="flex items-center mt-2 gap-2">
                <Input readOnly value={getEditableUrl()} />
                <Button variant="outline" onClick={handleCopyEditable}>
                  <span className="inline-flex justify-center w-[48px]">
                    {copiedEditable ? <Check className="w-4 h-4 text-green-600" /> : 'Copy'}
                  </span>
                </Button>
              </div>
              <SocialShareButtons url={getEditableUrl()} />
            </TabsContent>

            <TabsContent value="view">
              <p className="text-sm text-gray-600 mb-2">Invite the recipient to view the card.</p>
              <MultiEmailInput value={viewerEmails} onChange={setViewerEmails} />
              <Button
                disabled={sending || viewerEmails.length === 0}
                onClick={() => handleInvite(viewerEmails, 'view')}
                className="mb-4"
              >
                {sending ? 'Sending...' : 'Send Invite'}
              </Button>
              <div className="text-sm text-gray-700 mt-2 font-medium">
                Or share this link via text, Slack, or WhatsApp, etc.
              </div>
              <p className="text-xs text-gray-500 mb-1">
                Anyone with the link can access the card.
              </p>
              <div className="flex items-center mt-2 gap-2">
                <Input readOnly value={getViewableUrl()} />
                <Button variant="outline" onClick={handleCopyViewable}>
                  <span className="inline-flex justify-center w-[48px]">
                    {copiedViewable ? <Check className="w-4 h-4 text-green-600" /> : 'Copy'}
                  </span>
                </Button>
              </div>
              <SocialShareButtons url={getViewableUrl()} />
            </TabsContent>
          </Tabs>
        )}
      </DialogContent>
    </Dialog>
  );
};

export default ShareDialog;
