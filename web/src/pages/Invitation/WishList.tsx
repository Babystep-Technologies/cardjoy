import React from 'react';
import { gql, useQuery } from '@apollo/client';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Gift, Wallet, ArrowLeft, ExternalLink, Copy, Share2, Info } from 'lucide-react';
import { Toaster, toast } from 'sonner';
import LoadingScreen from '@/components/Loading';
import {
  contributionKindMeta,
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

const ItemCard: React.FC<{ item: WishListItem }> = ({ item }) => (
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
        <h3 className="font-bold text-lg leading-tight">{item.title}</h3>
        <div className="flex flex-wrap items-center gap-x-3 gap-y-1 text-sm text-gray-600">
          {item.price && <span className="font-semibold text-gray-900">{item.price}</span>}
          {item.quantity > 1 && <span>Wants {item.quantity}</span>}
          {item.store && <span className="truncate">{item.store}</span>}
        </div>
        {item.note && <p className="text-sm text-gray-600">{item.note}</p>}
        {item.url && (
          <Button asChild variant="outline" size="sm" className="mt-2 border-2">
            <a href={item.url} target="_blank" rel="noopener noreferrer">
              {item.store ? `Buy on ${item.store}` : 'View item'}
              <ExternalLink className="w-3.5 h-3.5 ml-1.5" />
            </a>
          </Button>
        )}
      </div>
    </CardContent>
  </Card>
);

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
