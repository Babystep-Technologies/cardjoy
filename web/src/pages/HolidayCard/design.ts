/**
 * Reading and writing the design document.
 *
 * `updateHolidayCard` **replaces** `design_config` rather than merging it, so the
 * editor holds the whole document and sends it back on every save. Every helper
 * here is therefore pure: take a document, return a new one. Nothing mutates in
 * place, which is what lets the autosave hook compare documents by identity to
 * decide whether anything actually changed.
 */
import type {
  DesignConfig,
  HolidayCardTemplate,
  PanelConfig,
  PanelName,
  PhotoPlacement,
  StickerPlacement,
  TextPlacement,
} from './types';
import { PANEL_NAMES } from './types';

/** A valid, empty document — the same shape `CreateHolidayCard` seeds. */
export function emptyDesign(version: number): DesignConfig {
  return {
    version,
    front: { photos: {}, texts: {}, stickers: [] },
    back: { photos: {}, texts: {}, stickers: [] },
  };
}

/**
 * The stored document, normalised.
 *
 * A card saved by an older release, or one whose panels were never written, is a
 * normal state rather than an error — the same tolerance `PrintRenderer#panel_config`
 * shows. The stored `version` is preserved: rewriting it here would silently
 * claim a document had been migrated when nothing had touched its contents.
 */
export function normalizeDesign(
  config: DesignConfig | null | undefined,
  version: number
): DesignConfig {
  return {
    version: config?.version ?? version,
    front: normalizePanel(config?.front),
    back: normalizePanel(config?.back),
  };
}

function normalizePanel(panel: PanelConfig | undefined): PanelConfig {
  return {
    photos: panel?.photos ?? {},
    texts: panel?.texts ?? {},
    stickers: Array.isArray(panel?.stickers) ? panel.stickers : [],
  };
}

export function panelOf(config: DesignConfig, panel: PanelName): PanelConfig {
  return normalizePanel(config[panel]);
}

function withPanel(config: DesignConfig, panel: PanelName, next: PanelConfig): DesignConfig {
  return { ...config, [panel]: next };
}

// ------------------------------------------------------------------- photos

export function photoPlacement(
  config: DesignConfig,
  panel: PanelName,
  slotId: string
): PhotoPlacement | undefined {
  return panelOf(config, panel).photos?.[slotId];
}

export function setPhotoPlacement(
  config: DesignConfig,
  panel: PanelName,
  slotId: string,
  placement: PhotoPlacement
): DesignConfig {
  const current = panelOf(config, panel);
  return withPanel(config, panel, {
    ...current,
    photos: { ...current.photos, [slotId]: placement },
  });
}

export function clearPhotoPlacement(
  config: DesignConfig,
  panel: PanelName,
  slotId: string
): DesignConfig {
  const current = panelOf(config, panel);
  const photos = { ...current.photos };
  delete photos[slotId];
  return withPanel(config, panel, { ...current, photos });
}

/**
 * Drops every placement pointing at a blob, in every panel.
 *
 * `deleteHolidayCardPhoto` does the same scrub server-side, and the model
 * rejects a document referencing a photo that is not attached — so the editor
 * has to stop showing a deleted photo *before* its next autosave fires, or that
 * save comes back as a validation error the user did nothing to cause.
 */
export function scrubBlob(config: DesignConfig, blobId: string): DesignConfig {
  return PANEL_NAMES.reduce((next, panel) => {
    const current = panelOf(next, panel);
    const photos = Object.fromEntries(
      Object.entries(current.photos ?? {}).filter(
        ([, placement]) => String(placement.blob_id) !== String(blobId)
      )
    );
    return withPanel(next, panel, { ...current, photos });
  }, config);
}

// -------------------------------------------------------------------- texts

export function textPlacement(
  config: DesignConfig,
  panel: PanelName,
  regionId: string
): TextPlacement | undefined {
  return panelOf(config, panel).texts?.[regionId];
}

export function setTextPlacement(
  config: DesignConfig,
  panel: PanelName,
  regionId: string,
  placement: TextPlacement
): DesignConfig {
  const current = panelOf(config, panel);
  return withPanel(config, panel, {
    ...current,
    texts: { ...current.texts, [regionId]: placement },
  });
}

// ----------------------------------------------------------------- stickers

export function stickerIn(
  config: DesignConfig,
  panel: PanelName,
  regionId: string
): StickerPlacement | undefined {
  return panelOf(config, panel).stickers?.find(placement => placement.region_id === regionId);
}

/** One sticker per region: a region is a slot, not a canvas. */
export function setSticker(
  config: DesignConfig,
  panel: PanelName,
  regionId: string,
  stickerId: string
): DesignConfig {
  const current = panelOf(config, panel);
  const others = (current.stickers ?? []).filter(placement => placement.region_id !== regionId);
  return withPanel(config, panel, {
    ...current,
    stickers: [...others, { region_id: regionId, sticker_id: stickerId }],
  });
}

export function clearSticker(
  config: DesignConfig,
  panel: PanelName,
  regionId: string
): DesignConfig {
  const current = panelOf(config, panel);
  return withPanel(config, panel, {
    ...current,
    stickers: (current.stickers ?? []).filter(placement => placement.region_id !== regionId),
  });
}

// -------------------------------------------------------- template switching

/** What a template switch could not carry across, in words a user can act on. */
export interface RemapResult {
  config: DesignConfig;
  dropped: string[];
}

/**
 * Re-lays a design out on a different template.
 *
 * Content is carried across **by index**: the first photo slot's photo goes to
 * the new first photo slot, and so on. Nothing else is available to match on —
 * slot ids are per-template and a "greeting" on one layout is not necessarily
 * the same region on another — and index at least preserves reading order,
 * which is how the user chose the arrangement in the first place.
 *
 * Anything with no slot to land in is reported rather than dropped quietly.
 * Silently discarding somebody's message because they clicked a different layout
 * is the fastest way to lose them, so the caller shows this list and lets them
 * undo by switching back — the old document is still theirs until the next save.
 */
export function remapDesign(
  config: DesignConfig,
  from: HolidayCardTemplate,
  to: HolidayCardTemplate
): RemapResult {
  const dropped: string[] = [];
  let next: DesignConfig = { version: config.version, front: {}, back: {} };

  for (const panel of PANEL_NAMES) {
    const source = panelOf(config, panel);
    const fromPanel = from[panel];
    const toPanel = to[panel];

    const photos: Record<string, PhotoPlacement> = {};
    fromPanel.photoSlots.forEach((slot, index) => {
      const placement = source.photos?.[slot.id];
      if (!placement) return;

      const target = toPanel.photoSlots[index];
      if (target) photos[target.id] = placement;
      else dropped.push(`a photo on the ${panel}`);
    });

    const texts: Record<string, TextPlacement> = {};
    fromPanel.textRegions.forEach((region, index) => {
      const placement = source.texts?.[region.id];
      if (!placement) return;

      const target = toPanel.textRegions[index];
      // An empty override carries no work worth warning about, so it is dropped
      // without a message — otherwise every switch would warn about regions the
      // user only ever clicked into.
      if (target) texts[target.id] = placement;
      else if (placement.content?.trim())
        dropped.push(`the message "${preview(placement.content)}" on the ${panel}`);
    });

    const stickers: StickerPlacement[] = [];
    fromPanel.stickerRegions.forEach((region, index) => {
      const placement = source.stickers?.find(sticker => sticker.region_id === region.id);
      if (!placement) return;

      const target = toPanel.stickerRegions[index];
      if (target) stickers.push({ ...placement, region_id: target.id });
      else dropped.push(`a sticker on the ${panel}`);
    });

    next = withPanel(next, panel, { photos, texts, stickers });
  }

  return { config: next, dropped };
}

/** A message, shortened enough to name it in a warning without filling the toast. */
function preview(content: string): string {
  const trimmed = content.trim().replace(/\s+/g, ' ');
  return trimmed.length > 40 ? `${trimmed.slice(0, 40)}…` : trimmed;
}

/**
 * Whether two documents differ. Used by the autosave hook to avoid sending a
 * save for a change that turned out to be a no-op — clicking into a text region
 * and back out, say.
 *
 * Key order is irrelevant here for the same reason it is irrelevant to the
 * server's proof digest: the same design reaches us in more than one shape.
 */
export function designsEqual(a: DesignConfig, b: DesignConfig): boolean {
  return canonical(a) === canonical(b);
}

function canonical(value: unknown): string {
  return JSON.stringify(sortKeys(value));
}

/** Sorted keys all the way down. Arrays keep their order — a sticker list is a paint order. */
function sortKeys(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(sortKeys);
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>)
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([key, nested]) => [key, sortKeys(nested)])
    );
  }
  return value;
}
