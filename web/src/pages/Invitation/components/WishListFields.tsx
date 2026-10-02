import React, { useState } from 'react';
import { gql, useMutation } from '@apollo/client';
import { Button } from '@/components/ui/button';
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
import { Gift, Plus, Trash2, Wallet, Info, Loader2 } from 'lucide-react';
import {
  CONTRIBUTION_KINDS,
  contributionKindMeta,
  emptyWishListContribution,
  emptyWishListItem,
  PREVIEW_WISH_LIST_LINK_MUTATION,
  TRUMP_ACCOUNT_INFO_URL,
  type ContributionKind,
  type WishListContribution,
  type WishListDraft,
  type WishListItem,
} from '@/lib/wishList';

const PREVIEW_WISH_LIST_LINK = gql(PREVIEW_WISH_LIST_LINK_MUTATION);

interface Props {
  value: WishListDraft;
  onChange: (draft: WishListDraft) => void;
  /** The create flow has no invitation yet, so it hides the publish toggle. */
  showVisibilityToggle?: boolean;
  idPrefix?: string;
}

const WishListFields: React.FC<Props> = ({
  value,
  onChange,
  showVisibilityToggle = true,
  idPrefix = 'wishList',
}) => {
  const patch = (changes: Partial<WishListDraft>) => onChange({ ...value, ...changes });

  const updateItem = (index: number, changes: Partial<WishListItem>) =>
    patch({
      items: value.items.map((item, i) => (i === index ? { ...item, ...changes } : item)),
    });

  const [previewWishListLink] = useMutation(PREVIEW_WISH_LIST_LINK);
  const [fetchingPreviewIndex, setFetchingPreviewIndex] = useState<number | null>(null);
  const [previewedUrls, setPreviewedUrls] = useState<Record<number, string>>({});

  const fetchLinkPreview = async (index: number) => {
    const item = value.items[index];
    const url = item?.url?.trim();
    if (!url || previewedUrls[index] === url) return;

    setPreviewedUrls(prev => ({ ...prev, [index]: url }));
    setFetchingPreviewIndex(index);
    try {
      const { data } = await previewWishListLink({ variables: { input: { url } } });
      const preview = data?.previewWishListLink?.preview;
      if (!preview) return;

      // Never clobber anything the host already typed -- the preview only fills blanks.
      const current = value.items[index];
      if (!current || current.url?.trim() !== url) return;

      updateItem(index, {
        title: current.title.trim() ? current.title : preview.title,
        imageUrl: current.imageUrl?.trim() ? current.imageUrl : preview.imageUrl,
        price: current.price?.trim() ? current.price : preview.price,
        store: current.store?.trim() ? current.store : preview.store,
      });
    } catch (error) {
      console.error('Failed to preview wish list link', error);
    } finally {
      setFetchingPreviewIndex(null);
    }
  };

  const updateContribution = (index: number, changes: Partial<WishListContribution>) =>
    patch({
      contributions: value.contributions.map((contribution, i) =>
        i === index ? { ...contribution, ...changes } : contribution
      ),
    });

  return (
    <div className="space-y-6">
      <div className="space-y-2">
        <Label htmlFor={`${idPrefix}Title`} className="text-base font-semibold">
          Title
        </Label>
        <Input
          id={`${idPrefix}Title`}
          value={value.title}
          onChange={e => patch({ title: e.target.value })}
          placeholder="Wish List"
        />
      </div>

      <div className="space-y-2">
        <Label htmlFor={`${idPrefix}Intro`} className="text-base font-semibold">
          Note to guests (Optional)
        </Label>
        <Textarea
          id={`${idPrefix}Intro`}
          value={value.intro}
          onChange={e => patch({ intro: e.target.value })}
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
          <Button
            variant="outline"
            size="sm"
            onClick={() => patch({ items: [...value.items, emptyWishListItem()] })}
          >
            <Plus className="w-4 h-4 mr-1" />
            Add item
          </Button>
        </div>

        {value.items.length === 0 && (
          <p className="text-sm text-gray-500">
            No gift ideas yet. Add one with a name, and optionally a link and price.
          </p>
        )}

        {value.items.map((item, index) => (
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
                onClick={() => patch({ items: value.items.filter((_, i) => i !== index) })}
              >
                <Trash2 className="w-4 h-4 text-red-500" />
              </Button>
            </div>
            <div className="space-y-1">
              <div className="flex items-center gap-2">
                {item.imageUrl && (
                  <img
                    src={item.imageUrl}
                    alt=""
                    className="w-8 h-8 object-cover rounded border border-gray-200 shrink-0"
                  />
                )}
                <Input
                  value={item.url ?? ''}
                  onChange={e => updateItem(index, { url: e.target.value })}
                  onBlur={() => fetchLinkPreview(index)}
                  placeholder="https://store.com/product (optional)"
                  aria-label={`Gift idea ${index + 1} link`}
                />
              </div>
              {fetchingPreviewIndex === index && (
                <p className="text-xs text-gray-500 flex items-center gap-1">
                  <Loader2 className="w-3 h-3 animate-spin" />
                  Fetching a preview...
                </p>
              )}
            </div>
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
            onClick={() =>
              patch({ contributions: [...value.contributions, emptyWishListContribution()] })
            }
          >
            <Plus className="w-4 h-4 mr-1" />
            Add option
          </Button>
        </div>

        <p className="text-sm text-gray-500 flex items-start gap-2">
          <Info className="w-4 h-4 mt-0.5 shrink-0" />
          Guests pay you directly in your own app. CardJoy never holds or handles the money.
        </p>

        {value.contributions.map((contribution, index) => {
          const meta = contributionKindMeta(contribution.kind);
          return (
            <div key={index} className="rounded-lg border-2 border-gray-200 p-4 space-y-3">
              <div className="flex items-start gap-2">
                <Select
                  value={contribution.kind}
                  onValueChange={kind =>
                    updateContribution(index, { kind: kind as ContributionKind })
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
                  onClick={() =>
                    patch({ contributions: value.contributions.filter((_, i) => i !== index) })
                  }
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
        {showVisibilityToggle && (
          <div className="flex items-center justify-between gap-4">
            <div>
              <Label htmlFor={`${idPrefix}Visible`} className="text-base font-semibold">
                Show on the invitation
              </Label>
              <p className="text-sm text-gray-500">
                Turn this off while you're still putting the list together.
              </p>
            </div>
            <Switch
              id={`${idPrefix}Visible`}
              checked={value.visible}
              onCheckedChange={visible => patch({ visible })}
            />
          </div>
        )}

        <div className="flex items-center justify-between gap-4">
          <div>
            <Label htmlFor={`${idPrefix}Surprise`} className="text-base font-semibold">
              Keep gifts a surprise
            </Label>
            <p className="text-sm text-gray-500">
              Hide who claimed what from you. Guests still see what's taken.
            </p>
          </div>
          <Switch
            id={`${idPrefix}Surprise`}
            checked={value.surpriseMode}
            onCheckedChange={surpriseMode => patch({ surpriseMode })}
          />
        </div>
      </div>
    </div>
  );
};

export default WishListFields;
