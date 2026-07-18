import React, { useState, useEffect, useMemo } from 'react';
import { Link } from 'react-router-dom';
import { gql, useQuery, useMutation } from '@apollo/client';
import { CardKind, CardType } from '@/types/app';
import { Button } from '@/components/ui/button';
import { useAuth } from '@/contexts/AuthContext';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import LoadingScreen from '@/components/Loading';
import ErrorScreen from '@/components/Error';
import { Toaster, toast } from 'sonner';
import withAuth from '@/lib/with-auth';
import CardQrCode from '@/pages/Card/components/QrCode';
import ShareDialog from '@/components/ShareDialog';
import { CardsList } from '@/components/Dashboard/CardsList';
import { InvitationsList } from '@/components/Dashboard/InvitationsList';

const GET_USER_CARDS = gql`
  query UserCards($userId: ID!) {
    userCards(userId: $userId) {
      externalId
      slug
      title
      kind
      locked
      recipients
      coverImageUrl
      deliverAt
      deliverToEmail
      styles {
        name
        kind
        value
      }
    }
  }
`;

const GET_USER_INVITATIONS = gql`
  query UserInvitations($userId: ID!) {
    userInvitations(userId: $userId) {
      externalId
      slug
      title
      description
      location
      eventDate
      eventTime
      eventTimezone
      coverImageUrl
    }
  }
`;

const DELETE_CARD = gql`
  mutation DeleteCard($input: DeleteCardInput!) {
    deleteCard(input: $input) {
      success
      errors
    }
  }
`;

// One entry per card kind, in tab order. Adding a kind (e.g. holiday) means adding an
// entry here — the first entry doubles as the fallback bucket, see cardsByKind below.
const CARD_TABS: {
  kind: CardKind;
  label: string;
  shortLabel: string;
  createPath: string;
  createLabel: string;
  emptyTitle: string;
  emptyDescription: string;
}[] = [
  {
    kind: 'group',
    label: 'Group Cards',
    shortLabel: 'Group',
    createPath: '/group-card/new',
    createLabel: 'Create New Card',
    emptyTitle: `You haven't created any group cards yet`,
    emptyDescription: `Get started by creating your first card — it's quick and easy!`,
  },
  {
    kind: 'one_on_one',
    label: '1-on-1 Cards',
    shortLabel: '1-on-1',
    createPath: '/one-on-one-card/new',
    createLabel: 'Send a 1-on-1 card',
    emptyTitle: `You haven't sent any 1-on-1 cards yet`,
    emptyDescription: 'Pick a design, write your message, and send it — no group signing needed.',
  },
];

const Dashboard: React.FC = () => {
  const { user } = useAuth();
  // Null until the user picks a tab, so the default can follow the data once it loads.
  const [activeTab, setActiveTab] = useState<string | null>(null);
  const [openDeleteConfirm, setOpenDeleteConfirm] = useState(false);
  const [shareDialogOpen, setShareDialogOpen] = useState(false);
  const [selectedCardId, setSelectedCardId] = useState<string | null>(null);
  const [selectedItemType, setSelectedItemType] = useState<'card' | 'invitation'>('card');
  const [qrCardId, setQrCardId] = useState<string | null>(null);

  const [deleteCard] = useMutation(DELETE_CARD);

  const { data, loading, error, refetch } = useQuery(GET_USER_CARDS, {
    variables: { userId: user?.user_id },
    skip: !user?.user_id,
    fetchPolicy: 'network-only',
    nextFetchPolicy: 'network-only',
  });

  const {
    data: invitationsData,
    loading: invitationsLoading,
    refetch: refetchInvitations,
  } = useQuery(GET_USER_INVITATIONS, {
    variables: { userId: user?.user_id },
    skip: !user?.user_id,
    fetchPolicy: 'network-only',
    nextFetchPolicy: 'network-only',
  });

  const cards: CardType[] = useMemo(() => data?.userCards || [], [data]);
  const invitations = invitationsData?.userInvitations || [];

  // Bucket cards by kind for the per-kind tabs. A kind the API knows about but this UI
  // doesn't have a tab for yet falls back to the first tab, so no card ever goes missing.
  const cardsByKind = useMemo(() => {
    const buckets = Object.fromEntries(
      CARD_TABS.map(tab => [tab.kind, [] as CardType[]])
    ) as Record<string, CardType[]>;
    cards.forEach(card => {
      const bucket = buckets[card.kind] ?? buckets[CARD_TABS[0].kind];
      bucket.push(card);
    });
    return buckets;
  }, [cards]);

  // Land on the first kind the user actually has, so someone who only sends 1-on-1 cards
  // doesn't open the dashboard on an empty Group tab. A manual choice always wins.
  const selectedTab =
    activeTab ?? CARD_TABS.find(tab => cardsByKind[tab.kind].length > 0)?.kind ?? CARD_TABS[0].kind;

  // Listen for delete events from child components
  useEffect(() => {
    const handleDeleteCard = (e: Event) => {
      const customEvent = e as CustomEvent;
      setSelectedCardId(customEvent.detail.cardId);
      setOpenDeleteConfirm(true);
    };

    window.addEventListener('deleteCard', handleDeleteCard);
    return () => window.removeEventListener('deleteCard', handleDeleteCard);
  }, []);

  const confirmDelete = async () => {
    if (selectedCardId) {
      try {
        await deleteCard({ variables: { input: { cardId: selectedCardId } } });
        await refetch();
        toast.success('Card deleted successfully');
      } catch {
        toast.error('Failed to delete card');
      }
      setOpenDeleteConfirm(false);
      setSelectedCardId(null);
    }
  };

  const handleCardShareClick = (cardId: string) => {
    setSelectedCardId(cardId);
    setSelectedItemType('card');
    setShareDialogOpen(true);
  };

  const handleInvitationShareClick = (invitationId: string) => {
    setSelectedCardId(invitationId);
    setSelectedItemType('invitation');
    setShareDialogOpen(true);
  };

  if (loading && invitationsLoading) return <LoadingScreen />;
  if (error) return <ErrorScreen />;

  const hasCards = cards.length > 0;
  const hasInvitations = invitations.length > 0;
  const hasAnyContent = hasCards || hasInvitations;

  return (
    <div className="flex flex-col flex-grow min-h-[calc(100vh-4rem)] p-4">
      <Toaster />

      {!hasAnyContent ? (
        <div className="flex flex-col items-center justify-center flex-grow text-center space-y-8 mt-8">
          <img src="/logo.svg" alt="CardJoy Logo" className="opacity-80 w-24 h-24" />
          <div className="space-y-2">
            <h2 className="text-2xl font-semibold text-gray-800">Welcome to CardJoy!</h2>
            <p className="text-gray-500 text-lg">
              Create group greeting cards, send a 1-on-1 card, or plan an event invitation to get
              started
            </p>
          </div>
          <div className="flex flex-col sm:flex-row gap-3">
            <Button asChild size="lg">
              <Link to="/group-card/new">Create a card</Link>
            </Button>
            <Button asChild size="lg" variant="outline">
              <Link to="/one-on-one-card/new">Send a 1-on-1 card</Link>
            </Button>
            <Button asChild size="lg" variant="outline">
              <Link to="/invitation/new">Create an invitation</Link>
            </Button>
          </div>
        </div>
      ) : (
        <div className="w-full max-w-7xl mx-auto mt-4 sm:mt-8 px-2 sm:px-4">
          <Tabs value={selectedTab} onValueChange={setActiveTab} className="w-full">
            <TabsList className="flex h-9 sm:h-10 items-center justify-center rounded-full bg-gray-100 p-1 mb-4 sm:mb-6 w-fit max-w-full mx-auto">
              {CARD_TABS.map(tab => (
                <TabsTrigger
                  key={tab.kind}
                  value={tab.kind}
                  className="rounded-full px-3 sm:px-6 py-1.5 sm:py-2 text-xs sm:text-sm font-medium transition-all data-[state=active]:bg-white data-[state=active]:shadow-sm whitespace-nowrap"
                >
                  <span className="sm:hidden">{tab.shortLabel}</span>
                  <span className="hidden sm:inline">{tab.label}</span>
                  {cardsByKind[tab.kind].length > 0 && `(${cardsByKind[tab.kind].length})`}
                </TabsTrigger>
              ))}
              <TabsTrigger
                value="invitations"
                className="rounded-full px-3 sm:px-6 py-1.5 sm:py-2 text-xs sm:text-sm font-medium transition-all data-[state=active]:bg-white data-[state=active]:shadow-sm whitespace-nowrap"
              >
                Invites{hasInvitations && ` (${invitations.length})`}
              </TabsTrigger>
            </TabsList>

            {CARD_TABS.map(tab => (
              <TabsContent key={tab.kind} value={tab.kind} className="mt-0">
                <CardsList
                  cards={cardsByKind[tab.kind]}
                  onRefetch={refetch}
                  onShareClick={handleCardShareClick}
                  onQrClick={setQrCardId}
                  createPath={tab.createPath}
                  createLabel={tab.createLabel}
                  emptyTitle={tab.emptyTitle}
                  emptyDescription={tab.emptyDescription}
                />
              </TabsContent>
            ))}

            <TabsContent value="invitations" className="mt-0">
              <InvitationsList
                invitations={invitations}
                onRefetch={refetchInvitations}
                onShareClick={handleInvitationShareClick}
              />
            </TabsContent>
          </Tabs>
        </div>
      )}

      {/* Share Dialog */}
      <ShareDialog
        open={shareDialogOpen && !!selectedCardId}
        onOpenChange={setShareDialogOpen}
        cardId={selectedCardId || ''}
        slug={
          selectedItemType === 'card'
            ? data?.userCards?.find((c: { externalId: string }) => c.externalId === selectedCardId)
                ?.slug
            : invitationsData?.userInvitations?.find(
                (i: { externalId: string }) => i.externalId === selectedCardId
              )?.slug
        }
        type={selectedItemType}
      />

      {/* QR Code Dialog */}
      {qrCardId && (
        <CardQrCode cardExternalId={qrCardId} open={true} onClose={() => setQrCardId(null)} />
      )}

      {/* Delete Confirmation Dialog */}
      <Dialog open={openDeleteConfirm} onOpenChange={setOpenDeleteConfirm}>
        <DialogContent className="p-6 w-96 text-black">
          <DialogHeader>
            <DialogTitle>Confirm Delete</DialogTitle>
          </DialogHeader>
          <p>Are you sure you want to delete this card? This action cannot be undone.</p>
          <div className="flex justify-end space-x-4 mt-4">
            <Button variant="outline" onClick={() => setOpenDeleteConfirm(false)}>
              Cancel
            </Button>
            <Button variant="destructive" onClick={confirmDelete}>
              Delete
            </Button>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
};

export default withAuth(Dashboard);
