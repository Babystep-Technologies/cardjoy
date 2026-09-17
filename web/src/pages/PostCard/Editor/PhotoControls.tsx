/**
 * Framing controls for the selected photo slot.
 *
 * Panning happens by dragging the photo in the preview, which is the direct
 * manipulation people expect; this is the zoom, the reset, and the place the
 * resolution warning gets explained properly rather than as a hover title.
 */
import React from 'react';
import { AlertTriangle, RotateCcw, Trash2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Label } from '@/components/ui/label';
import { clamp, effectivePhotoDpi, MIN_PHOTO_DPI } from '../geometry';
import { clearPhotoPlacement, photoPlacement, setPhotoPlacement } from '../design';
import type { DesignConfig, EditorOptions, PanelName, PhotoSlot } from '../types';

interface PhotoControlsProps {
  slot: PhotoSlot;
  panel: PanelName;
  config: DesignConfig;
  options: EditorOptions;
  naturalSize?: { width: number; height: number };
  onChange: (next: DesignConfig) => void;
}

export const PhotoControls: React.FC<PhotoControlsProps> = ({
  slot,
  panel,
  config,
  options,
  naturalSize,
  onChange,
}) => {
  const placement = photoPlacement(config, panel, slot.id);

  if (!placement) {
    return (
      <p className="text-sm text-gray-500">
        This slot is empty. Upload a photo or pick one from the ones already on this card.
      </p>
    );
  }

  const zoom = placement.zoom ?? 1;
  const dpi = effectivePhotoDpi(naturalSize, slot.rect, zoom);

  const setZoom = (next: number) =>
    onChange(
      setPhotoPlacement(config, panel, slot.id, {
        ...placement,
        zoom: clamp(next, options.minZoom, options.maxZoom),
      })
    );

  return (
    <div className="space-y-4">
      <p className="text-xs text-gray-500">
        Drag the photo on the card to move it inside this {slot.rect.w}″ × {slot.rect.h}″ window.
      </p>

      <div>
        <div className="flex items-baseline justify-between">
          <Label htmlFor="photo-zoom" className="text-xs text-gray-600">
            Zoom
          </Label>
          <span className="text-xs text-gray-400">{zoom.toFixed(2)}×</span>
        </div>
        <input
          id="photo-zoom"
          type="range"
          min={options.minZoom}
          max={options.maxZoom}
          step={0.01}
          value={zoom}
          onChange={event => setZoom(Number(event.target.value))}
          className="mt-1.5 w-full accent-[var(--color-brand-yellow)]"
        />
      </div>

      {dpi !== null && (
        <div
          className={`rounded-md border p-2.5 text-xs ${
            dpi < MIN_PHOTO_DPI
              ? 'border-amber-300 bg-amber-50 text-amber-900'
              : 'border-gray-200 bg-gray-50 text-gray-600'
          }`}
        >
          {dpi < MIN_PHOTO_DPI ? (
            <span className="flex gap-1.5">
              <AlertTriangle className="mt-0.5 h-3.5 w-3.5 shrink-0" />
              <span>
                About {Math.round(dpi)} DPI at this size and zoom — under {MIN_PHOTO_DPI} DPI this
                may look soft in print. Zooming out or using a larger original will help. You can
                print it as it is.
              </span>
            </span>
          ) : (
            <>Prints at about {Math.round(dpi)} DPI. That is plenty of detail for this slot.</>
          )}
        </div>
      )}

      <div className="flex gap-2">
        <Button
          type="button"
          variant="outline"
          size="sm"
          className="flex-1 gap-1.5"
          onClick={() =>
            onChange(
              setPhotoPlacement(config, panel, slot.id, {
                blob_id: placement.blob_id,
                pan_x: 0,
                pan_y: 0,
                zoom: 1,
              })
            )
          }
        >
          <RotateCcw className="h-3.5 w-3.5" />
          Recentre
        </Button>
        <Button
          type="button"
          variant="outline"
          size="sm"
          className="flex-1 gap-1.5 text-red-600 hover:text-red-700"
          // Empties the slot only. The photo stays on the card, so putting it in
          // another slot does not mean uploading it again.
          onClick={() => onChange(clearPhotoPlacement(config, panel, slot.id))}
        >
          <Trash2 className="h-3.5 w-3.5" />
          Clear slot
        </Button>
      </div>
    </div>
  );
};
