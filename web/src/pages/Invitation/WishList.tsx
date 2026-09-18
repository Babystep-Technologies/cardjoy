import React, { useState } from 'react';
import { gql, useMutation, useQuery } from '@apollo/client';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import {
  Gift,
  Wallet,
  ArrowLeft,
  ExternalLink,
  Copy,
  Share2,
  Info,
  CheckCircle2,
} from 'lucide-react';
import { Toaster, toast } from 'sonner';
import LoadingScreen from '@/components/Loading';
import { getWishListReservationTokenKey } from '@/lib/utils';
import {
  contributionKindMeta,
  RELEASE_WISH_LIST_RESERVATION_MUTATION,
  RESERVE_WISH_LIST_ITEM_MUTATION,
  TRUMP_ACCOUNT_INFO_URL,
  WISH_LIST_FIELDS,
  type WishListContribution,
  type WishListItem,
} from '@/lib/wishList';

// Named to match GraphqlController::PUBLIC_OPERATIONS so guests can load it signed out.
const GET_INVITATION_WISH_LIST = gql`
  query GetInvitationWishList($externalId: String!) {
    invitation(externalId: $externalId) {
      id
      externalId
      title
      eventDate
      wishList {
        ${WISH_LIST_FIELDS}
      }
    }
  }
`;

const RESERVE_WISH_LIST_ITEM = gql(RESERVE_WISH_LIST_ITEM_MUTATION);
const RELEASE_WISH_LIST_RESERVATION = gql(RELEASE_WISH_LIST_RESERVATION_MUTATION);

const ReserveDialog: React.FC<{
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onConfirm: (name: string, email: string) => Promise<void>;
}> = ({ open, onOpenChange, onConfirm }) => {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const handleConfirm = async () => {
    if (!name.trim() || !email.trim()) {
      toast.error('Please enter your name and email');
      return;
    }
    setSubmitting(true);
    try {
      await onConfirm(name.trim(), email.trim());
      onOpenChange(false);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-sm">
        <DialogHeader>
          <DialogTitle>I'm getting this</DialogTitle>
        </DialogHeader>
        <div className="space-y-3 py-2">
          <p className="text-sm text-gray-600">
            Just your name and email so we can mark it claimed. Nobody else will see your contact
            info.
          </p>
          <div className="space-y-1.5">
            <Label htmlFor="reserve-name">Your name</Label>
            <Input id="reserve-name" value={name} onChange={e => setName(e.target.value)} />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="reserve-email">Your email</Label>
            <Input
              id="reserve-email"
              type="email"
              value={email}
              onChange={e => setEmail(e.target.value)}
            />
          </div>
        </div>
        <DialogFooter>
          <Button
            onClick={handleConfirm}
            disabled={submitting}
            className="bg-gradient-to-r from-pink-500 to-purple-500 hover:opacity-90 text-white font-bold w-full disabled:opacity-50"
          >
            {submitting ? 'Claiming...' : 'Confirm'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
};

const ItemCard: React.FC<{ item: WishListItem }> = ({ item }) => {
  const tokenKey = item.id ? getWishListReservationTokenKey(item.id) : null;
  const [myToken, setMyToken] = useState<string | null>(() =>
    tokenKey ? localStorage.getItem(tokenKey) : null
  );
  const [dialogOpen, setDialogOpen] = useState(false);
  const [reserveWishListItem] = useMutation(RESERVE_WISH_LIST_ITEM);
  const [releaseWishListReservation] = useMutation(RELEASE_WISH_LIST_RESERVATION);

  const claimed = item.claimed ?? false;
  const remaining = item.remainingQuantity ?? item.quantity;

  const handleReserve = async (guestName: string, guestEmail: string) => {
    try {
      const { data } = await reserveWishListItem({
        variables: { input: { wishListItemId: item.id, guestName, guestEmail, quantity: 1 } },
      });
      const result = data?.reserveWishListItem;
      const errors: string[] = result?.errors ?? [];
      if (errors.length > 0) {
        toast.error(errors.join(', '));
        return;
      }
      if (result?.token && tokenKey) {
        localStorage.setItem(tokenKey, result.token);
        setMyToken(result.token);
      }
      toast.success("You're all set — marked as claimed!");
    } catch (error) {
      console.error('Failed to reserve wish list item', error);
      toast.error('Could not claim this item. Please try again.');
    }
  };

  const handleRelease = async () => {
    if (!myToken) return;
    try {
      const { data } = await releaseWishListReservation({
        variables: { input: { token: myToken } },
      });
      const errors: string[] = data?.releaseWishListReservation?.errors ?? [];
      if (errors.length > 0) {
        toast.error(errors.join(', '));
        return;
      }
      if (tokenKey) localStorage.removeItem(tokenKey);
      setMyToken(null);
      toast.success('Reservation released');
    } catch (error) {
      console.error('Failed to release wish list reservation', error);
      toast.error('Could not release this item. Please try again.');
    }
  };

  return (
    <Card className="border-2 border-gray-200 bg-white/95">
      <CardContent className="p-4 flex gap-4">
        {item.imageUrl && (
          <img
            src={item.imageUrl}
            alt=""
            className="w-20 h-20 object-cover rounded-lg border border-gray-200 shrink-0"
          />
        )}
        <div className="flex-1 min-w-0 space-y-1">
          <div className="flex items-start justify-between gap-2">
            <h3 className="font-bold text-lg leading-tight">{item.title}</h3>
            {myToken ? (
              <Badge className="bg-green-100 text-green-800 border border-green-300 shrink-0">
                <CheckCircle2 className="w-3.5 h-3.5 mr-1" />
                You're getting this
              </Badge>
            ) : claimed ? (
              <Badge variant="outline" className="border-gray-300 text-gray-500 shrink-0">
                Claimed
              </Badge>
            ) : null}
          </div>
          <div className="flex flex-wrap items-center gap-x-3 gap-y-1 text-sm text-gray-600">
            {item.price && <span className="font-semibold text-gray-900">{item.price}</span>}
            {item.quantity > 1 && (
              <span>
                {remaining} of {item.quantity} still wanted
              </span>
            )}
            {item.store && <span className="truncate">{item.store}</span>}
          </div>
          {item.note && <p className="text-sm text-gray-600">{item.note}</p>}
          <div className="flex flex-wrap gap-2 mt-2">
            {item.url && (
              <Button asChild variant="outline" size="sm" className="border-2">
                <a href={item.url} target="_blank" rel="noopener noreferrer">
                  {item.store ? `Buy on ${item.store}` : 'View item'}
                  <ExternalLink className="w-3.5 h-3.5 ml-1.5" />
                </a>
              </Button>
            )}
            {myToken ? (
              <Button variant="outline" size="sm" className="border-2" onClick={handleRelease}>
                Undo
              </Button>
            ) : (
              !claimed && (
                <Button
                  size="sm"
                  className="bg-gradient-to-r from-pink-500 to-purple-500 hover:opacity-90 text-white font-bold"
                  onClick={() => setDialogOpen(true)}
                >
                  <Gift className="w-3.5 h-3.5 mr-1.5" />
                  I'm getting this
                </Button>
              )
            )}
          </div>
        </div>
      </CardContent>
      <ReserveDialog open={dialogOpen} onOpenChange={setDialogOpen} onConfirm={handleReserve} />
    </Card>
  );
};

const ContributionCard: React.FC<{ contribution: WishListContribution }> = ({ contribution }) => {
  const meta = contributionKindMeta(contribution.kind);

  const copyHandle = async () => {
    try {
      await navigator.clipboard.writeText(contribution.handle);
      toast.success('Copied!');
    } catch {
      toast.error('Could not copy — you can select the text instead.');
    }
  };

  return (
    <Card className="border-2 border-gray-200 bg-white/95">
      <CardContent className="p-4 space-y-2">
        <div className="flex items-baseline justify-between gap-3">
          <h3 className="font-bold text-lg">{contribution.label || meta.label}</h3>
          {contribution.suggestedAmount && (
            <span className="text-sm font-semibold text-gray-900 shrink-0">
              {contribution.suggestedAmount}
            </span>
          )}
        </div>
        {contribution.label && <p className="text-sm text-gray-500">{meta.label}</p>}
        {contribution.note && <p className="text-sm text-gray-600">{contribution.note}</p>}

        {contribution.kind === 'trump_account' && (
          <p className="text-xs text-gray-500">
            A Trump Account is a tax-advantaged savings account for a child.{' '}
            <a
              href={TRUMP_ACCOUNT_INFO_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="underline"
            >
              Learn more at IRS.gov
            </a>
          </p>
        )}

        {contribution.actionUrl ? (
          <Button
            asChild
            className="w-full bg-gradient-to-r from-pink-500 to-purple-500 hover:opacity-90 text-white font-bold"
          >
            <a href={contribution.actionUrl} target="_blank" rel="noopener noreferrer">
              Send with {meta.label}
              <ExternalLink className="w-4 h-4 ml-1.5" />
            </a>
          </Button>
        ) : (
          <div className="space-y-1">
            <div className="flex items-center gap-2">
              <code className="flex-1 rounded-md bg-gray-100 px-3 py-2 text-sm break-all">
                {contribution.handle}
              </code>
              <Button variant="outline" size="icon" onClick={copyHandle} aria-label="Copy">
                <Copy className="w-4 h-4" />
              </Button>
            </div>
            <p className="text-xs text-gray-500">{meta.hint}</p>
          </div>
        )}
      </CardContent>
    </Card>
  );
};

const InvitationWishList: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();

  const { loading, data } = useQuery(GET_INVITATION_WISH_LIST, {
    variables: { externalId: id },
    skip: !id,
  });

  const invitation = data?.invitation;
  const wishList = invitation?.wishList;

  const share = async () => {
    const url = window.location.href;
    const shareData = {
      title: `${wishList?.title ?? 'Wish List'} — ${invitation?.title ?? ''}`.trim(),
      url,
    };

    if (navigator.share) {
      try {
        await navigator.share(shareData);
        return;
      } catch {
        // The guest dismissed the share sheet; fall through to copying.
      }
    }

    try {
      await navigator.clipboard.writeText(url);
      toast.success('Link copied!');
    } catch {
      toast.error('Could not copy the link.');
    }
  };

  if (loading) return <LoadingScreen />;

  if (!wishList) {
    return (
      <div className="flex flex-col flex-grow min-h-screen bg-gradient-to-br from-yellow-50 via-pink-50 to-blue-50">
        <div className="w-full mx-auto px-4 py-8 max-w-2xl mt-16 text-center space-y-4">
          <Gift className="w-12 h-12 mx-auto text-gray-400" />
          <h1 className="text-2xl font-bold">No wish list yet</h1>
          <p className="text-gray-600">This invitation doesn't have a wish list to show.</p>
          {id && (
            <Button
              variant="outline"
              className="border-2"
              onClick={() => navigate(`/invitation/${id}`)}
            >
              <ArrowLeft className="w-4 h-4 mr-2" />
              Back to invitation
            </Button>
          )}
        </div>
      </div>
    );
  }

  const items: WishListItem[] = wishList.items ?? [];
  const contributions: WishListContribution[] = wishList.contributions ?? [];

  return (
    <div className="flex flex-col flex-grow min-h-screen bg-gradient-to-br from-yellow-50 via-pink-50 to-blue-50">
      <div className="w-full mx-auto px-4 py-8 max-w-2xl mt-16 space-y-6">
        <Toaster />

        <Button variant="outline" className="border-2" asChild>
          <Link to={`/invitation/${id}`}>
            <ArrowLeft className="w-4 h-4 mr-2" />
            Back to invitation
          </Link>
        </Button>

        <div className="text-center space-y-2">
          <h1 className="text-4xl font-bold bg-gradient-to-r from-pink-500 to-purple-500 bg-clip-text text-transparent">
            {wishList.title}
          </h1>
          {invitation?.title && <p className="text-gray-600 text-lg">for {invitation.title}</p>}
          {wishList.intro && <p className="text-gray-700 max-w-lg mx-auto">{wishList.intro}</p>}
          <Button variant="outline" size="sm" className="border-2" onClick={share}>
            <Share2 className="w-4 h-4 mr-2" />
            Share this list
          </Button>
        </div>

        {items.length > 0 && (
          <section className="space-y-3">
            <h2 className="text-2xl font-bold flex items-center gap-2">
              <Gift className="w-5 h-5 text-pink-500" />
              Gift ideas
            </h2>
            {items.map((item, index) => (
              <ItemCard key={item.id ?? index} item={item} />
            ))}
          </section>
        )}

        {contributions.length > 0 && (
          <section className="space-y-3">
            <h2 className="text-2xl font-bold flex items-center gap-2">
              <Wallet className="w-5 h-5 text-purple-500" />
              Send a cash gift
            </h2>
            {contributions.map((contribution, index) => (
              <ContributionCard key={contribution.id ?? index} contribution={contribution} />
            ))}
            <p className="text-xs text-gray-500 flex items-start gap-2">
              <Info className="w-4 h-4 mt-0.5 shrink-0" />
              Payments happen in the host's own payment app. CardJoy never holds or handles your
              money, and takes no fee.
            </p>
          </section>
        )}

        {items.length === 0 && contributions.length === 0 && (
          <p className="text-center text-gray-600">
            The host hasn't added anything to this list yet.
          </p>
        )}
      </div>
    </div>
  );
};

export default InvitationWishList;
