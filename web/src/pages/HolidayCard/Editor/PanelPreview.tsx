/**
 * One side of the card, drawn from the server's inch coordinates.
 *
 * This is the component the whole feature stands on. It renders the same boxes
 * the print renderer emits — same absolute positions, same clipping, same
 * transform, same type scale — at `scale` pixels per inch instead of at print
 * DPI. Guides (safe margin, reserved address block, empty slots) are drawn
 * *over* that layer and are the only things here that will not print.
 *
 * It is also the interaction surface: photo slots are dragged to pan, text
 * regions are edited in place. Keeping those on top of the honest layer rather
 * than in a separate panel is deliberate — the user should be manipulating the
 * thing that prints, not a proxy for it.
 */
import React, { useCallback, useRef } from 'react';
import {
  boxStyle,
  overlapsReserved,
  photoImageStyle,
  photoTransform,
  textStyle,
} from '../geometry';
import type {
  DesignConfig,
  EditorOptions,
  HolidayCardPhoto,
  HolidayCardTemplate,
  PanelName,
  Sticker,
} from '../types';
import { photoPlacement, stickerIn, textPlacement } from '../design';
import { PhotoSlot } from './PhotoSlot';
import { TextRegion } from './TextRegion';

export type Selection = { kind: 'photo' | 'text' | 'sticker'; id: string } | null;

interface PanelPreviewProps {
  template: HolidayCardTemplate;
  panel: PanelName;
  config: DesignConfig;
  options: EditorOptions;
  photos: HolidayCardPhoto[];
  stickers: Sticker[];
  scale: number;
  /** Guides and drag handles. Off for the template picker's thumbnails. */
  interactive?: boolean;
  showGuides?: boolean;
  selection?: Selection;
  onSelect?: (selection: Selection) => void;
  onChange?: (next: DesignConfig) => void;
  /** Natural pixel size per blob id, for the low-resolution warning. */
  naturalSizes?: Record<string, { width: number; height: number }>;
  onPhotoLoad?: (blobId: string, size: { width: number; height: number }) => void;
}

export const PanelPreview: React.FC<PanelPreviewProps> = ({
  template,
  panel,
  config,
  options,
  photos,
  stickers,
  scale,
  interactive = false,
  showGuides = false,
  selection = null,
  onSelect,
  onChange,
  naturalSizes,
  onPhotoLoad,
}) => {
  const panelSpec = template[panel];
  const bleed = template.bleedInches;
  const surfaceRef = useRef<HTMLDivElement>(null);

  const width = (template.widthInches + bleed * 2) * scale;
  const height = (template.heightInches + bleed * 2) * scale;

  const photoByBlobId = useCallback(
    (blobId: string) => photos.find(photo => String(photo.blobId) === String(blobId)),
    [photos]
  );

  const stickerById = (id: string) => stickers.find(sticker => sticker.id === id);

  // Mirrors PrintRenderer#reserved? — a region overlapping the address block is
  // dropped at print time, so the preview must not show it either.
  const hidden = (rect: { x: number; y: number; w: number; h: number }) =>
    overlapsReserved(panel, rect, template.reservedAddressBlock);

  return (
    <div
      ref={surfaceRef}
      className="relative shadow-xl"
      style={{
        width,
        height,
        backgroundColor: panelSpec.background,
        // The trim line is where the card is actually cut. Everything outside it
        // is bleed, and clipping here is what makes the preview show the printed
        // piece rather than the printer's sheet.
        overflow: 'hidden',
      }}
      onPointerDown={event => {
        // A click on bare card deselects, so there is always a way out of a slot.
        if (interactive && event.target === surfaceRef.current) onSelect?.(null);
      }}
    >
      {/* ---------- photos (painted first, as in the renderer) ---------- */}
      {panelSpec.photoSlots.map(slot => {
        if (hidden(slot.rect)) return null;
        const placement = photoPlacement(config, panel, slot.id);
        const photo = placement ? photoByBlobId(placement.blob_id) : undefined;

        if (!interactive) {
          return (
            <div key={slot.id} style={boxStyle(slot.rect, scale, bleed, slot.radius)}>
              {photo?.url ? (
                <img
                  src={photo.url}
                  alt=""
                  style={photoImageStyle(photoTransform(placement, options))}
                />
              ) : (
                // A thumbnail of an empty layout is otherwise a plain rectangle
                // of background: the whole reason to show it is where the photos
                // go, so the empty slots have to be visible.
                showGuides && (
                  <div className="h-full w-full border border-dashed border-gray-400/70 bg-gray-200/60" />
                )
              )}
            </div>
          );
        }

        return (
          <PhotoSlot
            key={slot.id}
            slot={slot}
            panel={panel}
            config={config}
            options={options}
            photo={photo}
            scale={scale}
            bleed={bleed}
            selected={selection?.kind === 'photo' && selection.id === slot.id}
            showGuides={showGuides}
            naturalSize={placement ? naturalSizes?.[String(placement.blob_id)] : undefined}
            onSelect={() => onSelect?.({ kind: 'photo', id: slot.id })}
            onChange={onChange}
            onPhotoLoad={onPhotoLoad}
          />
        );
      })}

      {/* ---------- stickers, over the photos ---------- */}
      {panelSpec.stickerRegions.map(region => {
        if (hidden(region.rect)) return null;
        const placement = stickerIn(config, panel, region.id);
        const sticker = placement ? stickerById(placement.sticker_id) : undefined;
        const isSelected = selection?.kind === 'sticker' && selection.id === region.id;

        return (
          <div
            key={region.id}
            style={{
              ...boxStyle(region.rect, scale, bleed),
              ...(sticker
                ? {
                    backgroundImage: `url('${sticker.dataUri}')`,
                    backgroundRepeat: 'no-repeat',
                    backgroundPosition: 'center',
                    backgroundSize: 'contain',
                  }
                : {}),
              ...(interactive ? { cursor: 'pointer' } : {}),
            }}
            onPointerDown={event => {
              if (!interactive) return;
              event.stopPropagation();
              onSelect?.({ kind: 'sticker', id: region.id });
            }}
          >
            {interactive && showGuides && !sticker && (
              <div className="w-full h-full border border-dashed border-gray-400/70 rounded-[2px] flex items-center justify-center">
                <span className="text-[9px] leading-none text-gray-500/80 select-none">＋</span>
              </div>
            )}
            {interactive && isSelected && (
              <div className="absolute inset-0 ring-2 ring-[var(--color-brand-yellow)] pointer-events-none" />
            )}
          </div>
        );
      })}

      {/* ---------- text, on top of both ---------- */}
      {panelSpec.textRegions.map(region => {
        if (hidden(region.rect)) return null;
        const placement = textPlacement(config, panel, region.id);
        const style = textStyle(region, placement, panelSpec.background, scale, bleed, options);

        if (!interactive) {
          return (
            <div key={region.id} style={style}>
              {placement?.content ?? ''}
            </div>
          );
        }

        return (
          <TextRegion
            key={region.id}
            region={region}
            panel={panel}
            config={config}
            options={options}
            style={style}
            selected={selection?.kind === 'text' && selection.id === region.id}
            showGuides={showGuides}
            onSelect={() => onSelect?.({ kind: 'text', id: region.id })}
            onChange={onChange}
          />
        );
      })}

      {/* ---------- guides, which never print ---------- */}
      {showGuides && (
        <>
          {/* The safe margin: content outside it risks being trimmed off. */}
          <div
            className="absolute pointer-events-none border border-dashed border-sky-500/50"
            style={{
              left: (template.safeBox.x + bleed) * scale,
              top: (template.safeBox.y + bleed) * scale,
              width: template.safeBox.w * scale,
              height: template.safeBox.h * scale,
            }}
          />
          {/* The trim line itself — where the cutter comes down. */}
          <div
            className="absolute pointer-events-none border border-gray-400/50"
            style={{
              left: bleed * scale,
              top: bleed * scale,
              width: template.widthInches * scale,
              height: template.heightInches * scale,
            }}
          />
          {panel === 'back' && <ReservedBlock template={template} scale={scale} bleed={bleed} />}
        </>
      )}

      {/* Empty text regions get no visible placeholder in the printed layer, so
          the guide layer is where "there is something to write here" is said. */}
      {showGuides &&
        panelSpec.textRegions
          .filter(
            region => !hidden(region.rect) && !textPlacement(config, panel, region.id)?.content
          )
          .map(region => (
            <div
              key={`hint-${region.id}`}
              className="absolute pointer-events-none border border-dashed border-gray-400/60 rounded-[2px]"
              style={{
                left: (region.rect.x + bleed) * scale,
                top: (region.rect.y + bleed) * scale,
                width: region.rect.w * scale,
                height: region.rect.h * scale,
              }}
            />
          ))}
    </div>
  );
};

/**
 * PostGrid's territory on the back of the card: the recipient address, the
 * indicia, and the barcode clear zone.
 *
 * Drawn as an explicit, labelled no-go zone rather than left implicit. The user
 * has to understand that the right side of the back is not theirs — the
 * catalogue already refuses to place a slot there, so without this the space
 * just looks like room they are not being given.
 */
const ReservedBlock: React.FC<{ template: HolidayCardTemplate; scale: number; bleed: number }> = ({
  template,
  scale,
  bleed,
}) => {
  const block = template.reservedAddressBlock;

  return (
    <div
      className="absolute pointer-events-none flex items-center justify-center border-2 border-dashed border-red-400/70"
      style={{
        left: (block.x + bleed) * scale,
        top: (block.y + bleed) * scale,
        width: block.w * scale,
        height: block.h * scale,
        backgroundColor: 'rgba(248, 113, 113, 0.12)',
        backgroundImage:
          'repeating-linear-gradient(45deg, rgba(248,113,113,0.18) 0, rgba(248,113,113,0.18) 6px, transparent 6px, transparent 12px)',
      }}
    >
      <span className="px-2 text-center text-[11px] font-medium leading-tight text-red-700/90">
        Reserved for the
        <br />
        mailing address
      </span>
    </div>
  );
};
