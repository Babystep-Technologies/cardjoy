/**
 * One photo slot in the interactive preview.
 *
 * The slot is a fixed window with `overflow: hidden`; the user moves the photo
 * *behind* it and never moves the slot. That is not a UI preference — it is the
 * only model the print renderer can express, since `design_config` stores a pan
 * and a zoom and the geometry comes from the catalogue.
 *
 * Note what this deliberately does *not* do: it never crops the uploaded file.
 * `web/src/lib/crop-image.ts` bakes a crop into new bytes, which is right for a
 * card cover but wrong here — the server stores pan and zoom, so baking the crop
 * in would leave the placement un-adjustable after the fact and would not
 * survive a template switch onto a differently-shaped slot. The original photo
 * is uploaded once and re-framed as often as the user likes.
 */
import React, { useCallback, useRef, useState } from 'react';
import { AlertTriangle } from 'lucide-react';
import {
  boxStyle,
  clamp,
  effectivePhotoDpi,
  MIN_PHOTO_DPI,
  photoImageStyle,
  photoTransform,
} from '../geometry';
import { photoPlacement, setPhotoPlacement } from '../design';
import type {
  DesignConfig,
  EditorOptions,
  HolidayCardPhoto,
  PanelName,
  PhotoSlot as PhotoSlotSpec,
} from '../types';

interface PhotoSlotProps {
  slot: PhotoSlotSpec;
  panel: PanelName;
  config: DesignConfig;
  options: EditorOptions;
  photo?: HolidayCardPhoto;
  scale: number;
  bleed: number;
  selected: boolean;
  showGuides: boolean;
  naturalSize?: { width: number; height: number };
  onSelect: () => void;
  onChange?: (next: DesignConfig) => void;
  onPhotoLoad?: (blobId: string, size: { width: number; height: number }) => void;
}

export const PhotoSlot: React.FC<PhotoSlotProps> = ({
  slot,
  panel,
  config,
  options,
  photo,
  scale,
  bleed,
  selected,
  showGuides,
  naturalSize,
  onSelect,
  onChange,
  onPhotoLoad,
}) => {
  const placement = photoPlacement(config, panel, slot.id);
  const [dragging, setDragging] = useState(false);
  // The pan at the moment the drag started, plus the pointer origin. Held in a
  // ref so the move handler reads a stable base rather than accumulating
  // rounding error from its own output.
  const dragOrigin = useRef<{ x: number; y: number; panX: number; panY: number } | null>(null);

  const zoom = placement?.zoom ?? 1;
  const dpi = effectivePhotoDpi(naturalSize, slot.rect, zoom);
  const lowResolution = dpi !== null && dpi < MIN_PHOTO_DPI;

  const handlePointerDown = useCallback(
    (event: React.PointerEvent<HTMLDivElement>) => {
      event.stopPropagation();
      onSelect();
      if (!placement || !onChange) return;

      dragOrigin.current = {
        x: event.clientX,
        y: event.clientY,
        panX: placement.pan_x ?? 0,
        panY: placement.pan_y ?? 0,
      };
      setDragging(true);
      event.currentTarget.setPointerCapture(event.pointerId);
    },
    [onSelect, placement, onChange]
  );

  const handlePointerMove = useCallback(
    (event: React.PointerEvent<HTMLDivElement>) => {
      const origin = dragOrigin.current;
      if (!origin || !placement || !onChange) return;

      // Pan is a fraction of the slot, so pixels divide by the slot's own pixel
      // size — which makes a drag feel the same however far the preview is
      // zoomed out.
      const panX = clamp(
        origin.panX + (event.clientX - origin.x) / (slot.rect.w * scale),
        -options.maxPan,
        options.maxPan
      );
      const panY = clamp(
        origin.panY + (event.clientY - origin.y) / (slot.rect.h * scale),
        -options.maxPan,
        options.maxPan
      );

      onChange(
        setPhotoPlacement(config, panel, slot.id, { ...placement, pan_x: panX, pan_y: panY })
      );
    },
    [config, onChange, options.maxPan, panel, placement, scale, slot.id, slot.rect.h, slot.rect.w]
  );

  const endDrag = useCallback(() => {
    dragOrigin.current = null;
    setDragging(false);
  }, []);

  return (
    <div
      style={{
        ...boxStyle(slot.rect, scale, bleed, slot.radius),
        cursor: placement ? (dragging ? 'grabbing' : 'grab') : 'pointer',
        touchAction: 'none',
      }}
      onPointerDown={handlePointerDown}
      onPointerMove={handlePointerMove}
      onPointerUp={endDrag}
      onPointerCancel={endDrag}
    >
      {photo?.url && (
        <img
          src={photo.url}
          alt=""
          draggable={false}
          style={photoImageStyle(photoTransform(placement, options))}
          onLoad={event => {
            const image = event.currentTarget;
            if (placement) {
              onPhotoLoad?.(String(placement.blob_id), {
                width: image.naturalWidth,
                height: image.naturalHeight,
              });
            }
          }}
        />
      )}

      {!photo && showGuides && (
        <div className="w-full h-full flex items-center justify-center border border-dashed border-gray-400/80 bg-gray-100/60">
          <span
            className="text-gray-500 font-medium select-none"
            style={{ fontSize: Math.max(9, Math.min(13, slot.rect.w * scale * 0.09)) }}
          >
            Add photo
          </span>
        </div>
      )}

      {selected && (
        <div className="absolute inset-0 ring-2 ring-[var(--color-brand-yellow)] pointer-events-none" />
      )}

      {/* A warning, never a block: a 400px phone screenshot in a 3-inch slot
          prints as mush, but some people will want it anyway. */}
      {lowResolution && (
        <div
          className="absolute top-1 right-1 rounded-full bg-amber-500 text-white p-1 shadow pointer-events-none"
          title={`This photo is about ${Math.round(dpi)} DPI in this slot — below ${MIN_PHOTO_DPI} DPI it may print blurry.`}
        >
          <AlertTriangle className="w-3 h-3" />
        </div>
      )}
    </div>
  );
};
