import React from 'react';
import { Link } from 'react-router-dom';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Gift, ChevronRight } from 'lucide-react';
import type { WishList } from '@/lib/wishList';

const summarize = (wishList: WishList): string => {
  const hasItems = (wishList.items?.length ?? 0) > 0;
  const hasCash = (wishList.contributions?.length ?? 0) > 0;

  if (hasItems && hasCash) return 'Gift ideas + cash gifts';
  if (hasItems) return 'Gift ideas';
  if (hasCash) return 'Cash gifts';
  return 'See what the host has in mind';
};

interface Props {
  invitationId: string;
  wishList: WishList;
  /** Compact styling for use inside the dark post-RSVP confirmation card. */
  variant?: 'default' | 'onDark';
}

const WishListCallout: React.FC<Props> = ({ invitationId, wishList, variant = 'default' }) => {
  if (variant === 'onDark') {
    return (
      <div className="mt-4 pt-4 border-t border-white/10">
        <Link
          to={`/invitation/${invitationId}/wishlist`}
          className="flex items-center justify-center gap-2 text-sm text-white/80 hover:text-white transition-colors"
        >
          <Gift className="w-4 h-4" />
          <span>
            See the {wishList.title.toLowerCase()} — {summarize(wishList).toLowerCase()}
          </span>
          <ChevronRight className="w-4 h-4" />
        </Link>
      </div>
    );
  }

  return (
    <Card className="p-5 border-2 border-pink-200 bg-gradient-to-r from-pink-50 to-purple-50">
      <div className="flex items-start gap-3">
        <div className="w-10 h-10 rounded-full bg-white flex items-center justify-center shrink-0 shadow-sm">
          <Gift className="w-5 h-5 text-pink-500" />
        </div>
        <div className="flex-1 min-w-0">
          <h3 className="font-bold text-lg leading-tight">{wishList.title}</h3>
          <p className="text-sm text-gray-600">{summarize(wishList)}</p>
        </div>
      </div>
      <Button
        asChild
        className="w-full mt-4 bg-gradient-to-r from-pink-500 to-purple-500 hover:opacity-90 text-white font-bold h-12"
      >
        <Link to={`/invitation/${invitationId}/wishlist`}>🎁 View Wish List</Link>
      </Button>
    </Card>
  );
};

export default WishListCallout;
