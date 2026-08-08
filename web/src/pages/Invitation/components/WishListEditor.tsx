import React, { useEffect, useState } from 'react';
import { gql, useMutation } from '@apollo/client';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Gift, Plus } from 'lucide-react';
import { toast } from 'sonner';
import WishListFields from './WishListFields';
import {
  emptyWishListDraft,
  UPSERT_WISH_LIST_MUTATION,
  validateWishListDraft,
  wishListDraftToInput,
  wishListToDraft,
  type WishList,
  type WishListDraft,
} from '@/lib/wishList';

const UPSERT_WISH_LIST = gql(UPSERT_WISH_LIST_MUTATION);

interface Props {
  invitationExternalId: string;
  wishList?: WishList | null;
}

const WishListEditor: React.FC<Props> = ({ invitationExternalId, wishList }) => {
  const [enabled, setEnabled] = useState(false);
  const [draft, setDraft] = useState<WishListDraft>(emptyWishListDraft);
  const [saving, setSaving] = useState(false);

  const [upsertWishList] = useMutation(UPSERT_WISH_LIST);

  useEffect(() => {
    if (!wishList) return;
    setEnabled(true);
    setDraft(wishListToDraft(wishList));
  }, [wishList]);

  const handleSave = async () => {
    const problem = validateWishListDraft(draft);
    if (problem) {
      toast.error(problem);
      return;
    }

    setSaving(true);
    try {
      const { data } = await upsertWishList({
        variables: { input: { invitationExternalId, ...wishListDraftToInput(draft) } },
      });

      const errors: string[] = data?.upsertWishList?.errors ?? [];
      if (errors.length > 0) {
        toast.error(errors.join(', '));
      } else {
        toast.success('Wish list saved!');
      }
    } catch (error) {
      console.error('Failed to save wish list', error);
      toast.error('Failed to save the wish list. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  if (!enabled) {
    return (
      <Card className="shadow-xl border-2 border-gray-200 bg-white/95 backdrop-blur">
        <CardContent className="py-8 text-center space-y-3">
          <Gift className="w-10 h-10 mx-auto text-pink-500" />
          <h3 className="text-xl font-bold">Add a wish list</h3>
          <p className="text-gray-600 max-w-md mx-auto">
            Let guests know what to bring — gift ideas, cash gifts, or both. They'll see it right on
            the invitation.
          </p>
          <Button onClick={() => setEnabled(true)} className="border-2" variant="outline">
            <Plus className="w-4 h-4 mr-2" />
            Add wish list
          </Button>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className="shadow-xl border-2 border-gray-200 bg-white/95 backdrop-blur">
      <CardHeader className="border-b-2 border-dashed border-gray-200">
        <CardTitle className="flex items-center gap-2 text-2xl">
          <Gift className="w-6 h-6 text-pink-500" />
          Wish List
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-6 pt-6">
        <WishListFields value={draft} onChange={setDraft} />

        <div className="pt-2 flex justify-end">
          <Button
            onClick={handleSave}
            disabled={saving}
            className="bg-gradient-to-r from-pink-500 to-purple-500 hover:opacity-90 text-white font-bold h-12 px-6 disabled:opacity-50"
          >
            {saving ? 'Saving...' : 'Save wish list'}
          </Button>
        </div>
      </CardContent>
    </Card>
  );
};

export default WishListEditor;
