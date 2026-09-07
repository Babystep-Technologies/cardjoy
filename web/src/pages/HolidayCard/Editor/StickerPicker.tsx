/**
 * The sticker catalogue, for the currently selected sticker region.
 *
 * Stickers go into regions the template declares, not wherever the user drops
 * them. That is a deliberate constraint rather than a missing feature: free
 * placement would let someone put artwork over the address block or outside the
 * safe margin, and neither survives printing.
 *
 * Artwork arrives as a data URI because the API is API-only with no asset
 * pipeline to serve it from — the same bytes the print renderer embeds.
 */
import React from 'react';
import { X } from 'lucide-react';
import { Button } from '@/components/ui/button';
import type { Sticker } from '../types';

interface StickerPickerProps {
  stickers: Sticker[];
  /** The region being filled, or null when the user has not selected one. */
  regionId: string | null;
  selectedStickerId?: string;
  onSelect: (stickerId: string) => void;
  onClear: () => void;
}

export const StickerPicker: React.FC<StickerPickerProps> = ({
  stickers,
  regionId,
  selectedStickerId,
  onSelect,
  onClear,
}) => {
  if (!regionId) {
    return (
      <p className="text-sm text-gray-500">
        Pick one of the dashed sticker spots on the card to add a design element.
      </p>
    );
  }

  const categories = [...new Set(stickers.map(sticker => sticker.category))];

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-2">
        <span className="text-xs font-medium uppercase tracking-wide text-gray-500">
          {regionId.replace(/_/g, ' ')}
        </span>
        {selectedStickerId && (
          <Button
            type="button"
            variant="ghost"
            size="sm"
            onClick={onClear}
            className="h-7 gap-1 px-2"
          >
            <X className="w-3.5 h-3.5" />
            Remove
          </Button>
        )}
      </div>

      {categories.map(category => (
        <div key={category}>
          <p className="mb-2 text-xs font-medium capitalize text-gray-600">
            {category.replace(/_/g, ' ')}
          </p>
          <div className="grid grid-cols-4 gap-2">
            {stickers
              .filter(sticker => sticker.category === category)
              .map(sticker => (
                <button
                  key={sticker.id}
                  type="button"
                  title={sticker.name}
                  onClick={() => onSelect(sticker.id)}
                  className={`aspect-square rounded-md border-2 p-1.5 transition-colors ${
                    sticker.id === selectedStickerId
                      ? 'border-[var(--color-brand-yellow)] bg-amber-50'
                      : 'border-gray-200 hover:border-gray-400 bg-white'
                  }`}
                >
                  <img
                    src={sticker.dataUri}
                    alt={sticker.name}
                    className="h-full w-full object-contain"
                  />
                </button>
              ))}
          </div>
        </div>
      ))}

      {stickers.length === 0 && <p className="text-sm text-gray-500">No stickers available yet.</p>}
    </div>
  );
};
