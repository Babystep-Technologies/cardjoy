import React, { useEffect, useState } from 'react';
import { gql, useMutation } from '@apollo/client';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Switch } from '@/components/ui/switch';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Gift, Plus, Trash2, Wallet, Info } from 'lucide-react';
import { toast } from 'sonner';
import {
  CONTRIBUTION_KINDS,
  contributionKindMeta,
  TRUMP_ACCOUNT_INFO_URL,
  WISH_LIST_FIELDS,
  type ContributionKind,
  type WishList,
  type WishListContribution,
  type WishListItem,
} from '@/lib/wishList';

const UPSERT_WISH_LIST = gql`
  mutation UpsertWishList($input: UpsertWishListInput!) {
    upsertWishList(input: $input) {
      wishList {
        ${WISH_LIST_FIELDS}
      }
      errors
    }
  }
`;

const emptyItem = (): WishListItem => ({ title: '', url: '', price: '', note: '', quantity: 1 });

const emptyContribution = (): WishListContribution => ({
  kind: 'venmo',
  handle: '',
  label: '',
  suggestedAmount: '',
});

interface Props {
  invitationExternalId: string;
  wishList?: WishList | null;
}

const WishListEditor: React.FC<Props> = ({ invitationExternalId, wishList }) => {
  const [enabled, setEnabled] = useState(false);
  const [title, setTitle] = useState('Wish List');
  const [intro, setIntro] = useState('');
  const [visible, setVisible] = useState(true);
  const [surpriseMode, setSurpriseMode] = useState(true);
  const [items, setItems] = useState<WishListItem[]>([]);
  const [contributions, setContributions] = useState<WishListContribution[]>([]);
  const [saving, setSaving] = useState(false);

  const [upsertWishList] = useMutation(UPSERT_WISH_LIST);

  useEffect(() => {
    if (!wishList) return;
    setEnabled(true);
    setTitle(wishList.title || 'Wish List');
    setIntro(wishList.intro || '');
    setVisible(wishList.visible);
    setSurpriseMode(wishList.surpriseMode);
    setItems(
      wishList.items.map(item => ({
        title: item.title,
        url: item.url || '',
        price: item.price || '',
        note: item.note || '',
        quantity: item.quantity ?? 1,
      }))
    );
    setContributions(
      wishList.contributions.map(contribution => ({
        kind: contribution.kind,
        handle: contribution.handle,
        label: contribution.label || '',
        suggestedAmount: contribution.suggestedAmount || '',
      }))
    );
  }, [wishList]);

  const updateItem = (index: number, patch: Partial<WishListItem>) =>
    setItems(current => current.map((item, i) => (i === index ? { ...item, ...patch } : item)));

  const updateContribution = (index: number, patch: Partial<WishListContribution>) =>
    setContributions(current =>
      current.map((contribution, i) => (i === index ? { ...contribution, ...patch } : contribution))
    );

  const handleSave = async () => {
    if (items.some(item => !item.title.trim())) {
      toast.error('Every gift idea needs a name');
      return;
    }
    if (contributions.some(contribution => !contribution.handle.trim())) {
      toast.error('Every cash option needs a handle or instructions');
      return;
    }

    setSaving(true);
    try {
      const { data } = await upsertWishList({
        variables: {
          input: {
            invitationExternalId,
            title: title.trim() || 'Wish List',
            intro: intro.trim() || null,
            visible,
            surpriseMode,
            items: items.map(item => ({
              title: item.title.trim(),
              url: item.url?.trim() || null,
              price: item.price?.trim() || null,
              note: item.note?.trim() || null,
              quantity: item.quantity || 1,
            })),
            contributions: contributions.map(contribution => ({
              kind: contribution.kind,
              handle: contribution.handle.trim(),
              label: contribution.label?.trim() || null,
              suggestedAmount: contribution.suggestedAmount?.trim() || null,
            })),
          },
        },
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
        <div className="space-y-2">
          <Label htmlFor="wishListTitle" className="text-base font-semibold">
            Title
          </Label>
          <Input
            id="wishListTitle"
            value={title}
            onChange={e => setTitle(e.target.value)}
            placeholder="Wish List"
          />
        </div>

        <div className="space-y-2">
          <Label htmlFor="wishListIntro" className="text-base font-semibold">
            Note to guests (Optional)
          </Label>
          <Textarea
            id="wishListIntro"
            value={intro}
            onChange={e => setIntro(e.target.value)}
            placeholder="Your presence is the real gift, but if you'd like to bring something…"
            rows={3}
          />
        </div>

        {/* Gift ideas */}
        <div className="space-y-3">
          <div className="flex items-center justify-between">
            <Label className="text-base font-semibold flex items-center gap-2">
              <Gift className="w-4 h-4" />
              Gift ideas
            </Label>
            <Button variant="outline" size="sm" onClick={() => setItems([...items, emptyItem()])}>
              <Plus className="w-4 h-4 mr-1" />
              Add item
            </Button>
          </div>

          {items.length === 0 && (
            <p className="text-sm text-gray-500">
              No gift ideas yet. Add one with a name, and optionally a link and price.
            </p>
          )}

          {items.map((item, index) => (
            <div key={index} className="rounded-lg border-2 border-gray-200 p-4 space-y-3">
              <div className="flex items-start gap-2">
                <Input
                  value={item.title}
                  onChange={e => updateItem(index, { title: e.target.value })}
                  placeholder="Wooden play gym"
                  aria-label={`Gift idea ${index + 1} name`}
                />
                <Button
                  variant="ghost"
                  size="icon"
                  aria-label={`Remove gift idea ${index + 1}`}
                  onClick={() => setItems(items.filter((_, i) => i !== index))}
                >
                  <Trash2 className="w-4 h-4 text-red-500" />
                </Button>
              </div>
              <Input
                value={item.url ?? ''}
                onChange={e => updateItem(index, { url: e.target.value })}
                placeholder="https://store.com/product (optional)"
                aria-label={`Gift idea ${index + 1} link`}
              />
              <div className="grid grid-cols-2 gap-3">
                <Input
                  value={item.price ?? ''}
                  onChange={e => updateItem(index, { price: e.target.value })}
                  placeholder="$40 (optional)"
                  aria-label={`Gift idea ${index + 1} price`}
                />
                <Input
                  type="number"
                  min={1}
                  value={item.quantity}
                  onChange={e => updateItem(index, { quantity: Number(e.target.value) || 1 })}
                  aria-label={`Gift idea ${index + 1} quantity`}
                />
              </div>
              <Input
                value={item.note ?? ''}
                onChange={e => updateItem(index, { note: e.target.value })}
                placeholder="Size 2T, any color (optional)"
                aria-label={`Gift idea ${index + 1} note`}
              />
            </div>
          ))}
        </div>

        {/* Cash gifts */}
        <div className="space-y-3">
          <div className="flex items-center justify-between">
            <Label className="text-base font-semibold flex items-center gap-2">
              <Wallet className="w-4 h-4" />
              Cash gifts
            </Label>
            <Button
              variant="outline"
              size="sm"
              onClick={() => setContributions([...contributions, emptyContribution()])}
            >
              <Plus className="w-4 h-4 mr-1" />
              Add option
            </Button>
          </div>

          <p className="text-sm text-gray-500 flex items-start gap-2">
            <Info className="w-4 h-4 mt-0.5 shrink-0" />
            Guests pay you directly in your own app. CardJoy never holds or handles the money.
          </p>

          {contributions.map((contribution, index) => {
            const meta = contributionKindMeta(contribution.kind);
            return (
              <div key={index} className="rounded-lg border-2 border-gray-200 p-4 space-y-3">
                <div className="flex items-start gap-2">
                  <Select
                    value={contribution.kind}
                    onValueChange={value =>
                      updateContribution(index, { kind: value as ContributionKind })
                    }
                  >
                    <SelectTrigger aria-label={`Cash option ${index + 1} type`}>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {CONTRIBUTION_KINDS.map(kind => (
                        <SelectItem key={kind.value} value={kind.value}>
                          {kind.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  <Button
                    variant="ghost"
                    size="icon"
                    aria-label={`Remove cash option ${index + 1}`}
                    onClick={() => setContributions(contributions.filter((_, i) => i !== index))}
                  >
                    <Trash2 className="w-4 h-4 text-red-500" />
                  </Button>
                </div>

                <div className="space-y-1">
                  <Label className="text-sm">{meta.handleLabel}</Label>
                  <Input
                    value={contribution.handle}
                    onChange={e => updateContribution(index, { handle: e.target.value })}
                    placeholder={meta.handlePlaceholder}
                    aria-label={`Cash option ${index + 1} handle`}
                  />
                  {meta.hint && <p className="text-xs text-gray-500">{meta.hint}</p>}
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
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <Input
                    value={contribution.label ?? ''}
                    onChange={e => updateContribution(index, { label: e.target.value })}
                    placeholder="Toward the crib fund"
                    aria-label={`Cash option ${index + 1} label`}
                  />
                  <Input
                    value={contribution.suggestedAmount ?? ''}
                    onChange={e => updateContribution(index, { suggestedAmount: e.target.value })}
                    placeholder="$25 (optional)"
                    aria-label={`Cash option ${index + 1} suggested amount`}
                  />
                </div>
              </div>
            );
          })}
        </div>

        {/* Settings */}
        <div className="space-y-4 border-t-2 border-dashed border-gray-200 pt-4">
          <div className="flex items-center justify-between gap-4">
            <div>
              <Label htmlFor="wishListVisible" className="text-base font-semibold">
                Show on the invitation
              </Label>
              <p className="text-sm text-gray-500">
                Turn this off while you're still putting the list together.
              </p>
            </div>
            <Switch id="wishListVisible" checked={visible} onCheckedChange={setVisible} />
          </div>

          <div className="flex items-center justify-between gap-4">
            <div>
              <Label htmlFor="wishListSurprise" className="text-base font-semibold">
                Keep gifts a surprise
              </Label>
              <p className="text-sm text-gray-500">
                Hide who claimed what from you. Guests still see what's taken.
              </p>
            </div>
            <Switch
              id="wishListSurprise"
              checked={surpriseMode}
              onCheckedChange={setSurpriseMode}
            />
          </div>
        </div>

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
