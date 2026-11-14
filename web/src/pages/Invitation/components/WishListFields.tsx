import React, { useState } from 'react';
import { toast } from 'sonner';
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
import {
  Gift,
  Link2,
  Plus,
  Trash2,
  Wallet,
  Info,
  Loader2,
  ArrowUp,
  ArrowDown,
  Star,
} from 'lucide-react';
import {
  CONTRIBUTION_KINDS,
  contributionKindMeta,
  emptyWishListContribution,
  emptyWishListItem,
  MAX_PASTED_LINKS,
  parseLinks,
  PREVIEW_WISH_LIST_LINK_MUTATION,
  titleFromUrl,
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
  /** What turning visibility on shows, e.g. "Show on the invitation". */
  visibilityLabel?: string;
  /** Extra rows for the settings block, e.g. the registry's address sharing. */
  extraSettings?: React.ReactNode;
  idPrefix?: string;
}

const WishListFields: React.FC<Props> = ({
  value,
  onChange,
  showVisibilityToggle = true,
  visibilityLabel = 'Show on the invitation',
  extraSettings,
  idPrefix = 'wishList',
}) => {
  const patch = (changes: Partial<WishListDraft>) => onChange({ ...value, ...changes });

  const updateItem = (index: number, changes: Partial<WishListItem>) =>
    patch({
      items: value.items.map((item, i) => (i === index ? { ...item, ...changes } : item)),
    });

  // Swaps an item with its neighbour. The previewed-URL memo is keyed by row, so it moves with
  // the item; otherwise a reorder would refetch (or skip) the wrong row's link preview.
  const moveItem = (index: number, offset: -1 | 1) => {
    const target = index + offset;
    if (target < 0 || target >= value.items.length) return;
    const items = [...value.items];
    [items[index], items[target]] = [items[target], items[index]];
    setPreviewedUrls(prev => {
      const next = { ...prev };
      [next[index], next[target]] = [prev[target], prev[index]];
      return next;
    });
    patch({ items });
  };

  const [previewWishListLink] = useMutation(PREVIEW_WISH_LIST_LINK);
  const [fetchingPreviewIndex, setFetchingPreviewIndex] = useState<number | null>(null);
  const [previewedUrls, setPreviewedUrls] = useState<Record<number, string>>({});
  const [confirmClear, setConfirmClear] = useState(false);
  const [pasteOpen, setPasteOpen] = useState(false);
  const [pasteText, setPasteText] = useState('');
  const [pasting, setPasting] = useState(false);

  // Adds one item per pasted link, filled from its preview where the store allows one and with a
  // stand-in name where not. All previews are gathered first and applied in one update, so the
  // concurrent fetches can't overwrite each other.
  const addPastedLinks = async () => {
    const links = parseLinks(pasteText).slice(0, MAX_PASTED_LINKS);
    if (links.length === 0) {
      toast.error('Paste product links, one per line');
      return;
    }
    setPasting(true);
    try {
      const added: WishListItem[] = [];
      for (let i = 0; i < links.length; i += 4) {
        const batch = await Promise.all(
          links.slice(i, i + 4).map(async url => {
            let preview: {
              title?: string;
              imageUrl?: string;
              price?: string;
              store?: string;
            } | null = null;
            try {
              const { data } = await previewWishListLink({ variables: { input: { url } } });
              preview = data?.previewWishListLink?.preview ?? null;
            } catch (error) {
              console.error('Failed to preview wish list link', error);
            }
            return {
              ...emptyWishListItem(),
              url,
              title: preview?.title || titleFromUrl(url),
              imageUrl: preview?.imageUrl ?? '',
              price: preview?.price ?? '',
              store: preview?.store ?? '',
            };
          })
        );
        added.push(...batch);
      }
      patch({ items: [...value.items, ...added] });
      setPasteText('');
      setPasteOpen(false);
      toast.success(`Added ${added.length} ${added.length === 1 ? 'item' : 'items'}`);
    } finally {
      setPasting(false);
    }
  };

  const fetchLinkPreview = async (index: number) => {
    const item = value.items[index];
    const url = item?.url?.trim();
    if (!url || previewedUrls[index] === url) return;

    setPreviewedUrls(prev => ({ ...prev, [index]: url }));
    setFetchingPreviewIndex(index);
    try {
      const { data } = await previewWishListLink({ variables: { input: { url } } });
      const preview = data?.previewWishListLink?.preview;
      if (!preview) {
        // A store that blocks previews gets an explanation; other misses stay quiet, since typing
        // the item in by hand is always an option.
        const reason: string | undefined = data?.previewWishListLink?.errors?.find((e: string) =>
          e.includes("doesn't allow link previews")
        );
        if (reason) toast.info(reason);
        return;
      }

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
          <div className="flex flex-wrap justify-end gap-2">
            {value.items.length > 1 && (
              <Button
                variant="ghost"
                size="sm"
                className="text-red-600"
                onClick={() => {
                  if (!confirmClear) return setConfirmClear(true);
                  setConfirmClear(false);
                  patch({ items: [] });
                }}
                onBlur={() => setConfirmClear(false)}
              >
                <Trash2 className="w-4 h-4 mr-1" />
                {confirmClear ? `Really remove all ${value.items.length}?` : 'Remove all'}
              </Button>
            )}
            <Button
              variant="outline"
              size="sm"
              onClick={() =>
                patch({
                  items: [
                    ...value.items,
                    { ...emptyWishListItem(), title: 'Gift card', note: 'Any amount, any store' },
                  ],
                })
              }
            >
              <Gift className="w-4 h-4 mr-1" />
              Any gift card
            </Button>
            <Button variant="outline" size="sm" onClick={() => setPasteOpen(!pasteOpen)}>
              <Link2 className="w-4 h-4 mr-1" />
              Paste links
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={() => patch({ items: [...value.items, emptyWishListItem()] })}
            >
              <Plus className="w-4 h-4 mr-1" />
              Add item
            </Button>
          </div>
        </div>

        {pasteOpen && (
          <div className="space-y-2 rounded-lg border-2 border-gray-200 p-4">
            <Textarea
              value={pasteText}
              onChange={e => setPasteText(e.target.value)}
              placeholder={'Paste product links, one per line\nhttps://…'}
              rows={5}
              aria-label="Product links"
            />
            <div className="flex items-center justify-between gap-2">
              <p className="text-xs text-gray-500">
                Up to {MAX_PASTED_LINKS} at a time. Stores that block previews get a name from the
                link, which you can edit.
              </p>
              <Button size="sm" onClick={addPastedLinks} disabled={pasting || !pasteText.trim()}>
                {pasting ? 'Adding…' : 'Add items'}
              </Button>
            </div>
          </div>
        )}

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
                aria-label={`Mark gift idea ${index + 1} as most wanted`}
                aria-pressed={!!item.priority}
                onClick={() => updateItem(index, { priority: !item.priority })}
              >
                <Star
                  className={`w-4 h-4 ${item.priority ? 'fill-yellow-400 text-yellow-500' : 'text-gray-400'}`}
                />
              </Button>
              <Button
                variant="ghost"
                size="icon"
                aria-label={`Move gift idea ${index + 1} up`}
                disabled={index === 0}
                onClick={() => moveItem(index, -1)}
              >
                <ArrowUp className="w-4 h-4" />
              </Button>
              <Button
                variant="ghost"
                size="icon"
                aria-label={`Move gift idea ${index + 1} down`}
                disabled={index === value.items.length - 1}
                onClick={() => moveItem(index, 1)}
              >
                <ArrowDown className="w-4 h-4" />
              </Button>
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
            <Input
              value={item.section ?? ''}
              onChange={e => updateItem(index, { section: e.target.value })}
              placeholder="Section, e.g. Kitchen (optional)"
              aria-label={`Gift idea ${index + 1} section`}
              list={`${idPrefix}Sections`}
              maxLength={60}
            />
          </div>
        ))}
      </div>

      <datalist id={`${idPrefix}Sections`}>
        {Array.from(new Set(value.items.map(i => i.section?.trim()).filter(Boolean))).map(name => (
          <option key={name} value={name} />
        ))}
      </datalist>

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
                {visibilityLabel}
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

        {extraSettings}
      </div>
    </div>
  );
};

export default WishListFields;
