/**
 * The holiday card editor's view of the API.
 *
 * Two things cross the wire and they are deliberately kept apart, exactly as the
 * backend keeps them apart:
 *
 *  - **Geometry** (`HolidayCardTemplate`) — where `photo_2` sits, in inches from
 *    the top-left of the trimmed panel. Owned by `HolidayCardCatalogue`, fetched
 *    over GraphQL, never restated here. A slot coordinate typed into this file
 *    would be a second source of truth for print geometry, and drift there means
 *    a cropped face on a card that has already been mailed.
 *  - **Content** (`DesignConfig`) — which uploaded photo goes in that slot, and
 *    how it is panned and zoomed. Owned by `HolidayCard#design_config`, held in
 *    the editor and sent back wholesale on every save.
 *
 * Snake_case in `DesignConfig` is not a style slip: that document is stored as
 * jsonb and read by Ruby, so its keys are the API's keys.
 */

/** A rectangle in inches, measured from the top-left of the trimmed panel. */
export interface Rect {
  x: number;
  y: number;
  w: number;
  h: number;
}

export interface PhotoSlot {
  id: string;
  rect: Rect;
  /** Corner radius in inches. 0 is a square corner. */
  radius: number;
}

export interface TextRegion {
  id: string;
  rect: Rect;
  align: string;
  defaultFont: string;
  defaultSize: string;
}

export interface StickerRegion {
  id: string;
  rect: Rect;
}

export interface Panel {
  name: PanelName;
  /** `#rrggbb`, painted across the template's whole bleed box. */
  background: string;
  photoSlots: PhotoSlot[];
  textRegions: TextRegion[];
  stickerRegions: StickerRegion[];
}

export type PanelName = 'front' | 'back';

export const PANEL_NAMES: PanelName[] = ['front', 'back'];

export interface HolidayCardTemplate {
  id: string;
  name: string;
  description: string | null;
  size: string;
  widthInches: number;
  heightInches: number;
  bleedInches: number;
  safeMarginInches: number;
  bleedBox: Rect;
  safeBox: Rect;
  /** The back-panel region PostGrid prints the address, indicia, and barcode into. */
  reservedAddressBlock: Rect;
  front: Panel;
  back: Panel;
}

export interface Sticker {
  id: string;
  name: string;
  category: string;
  /** SVG as a data URI — the API has no asset pipeline to serve artwork from. */
  dataUri: string;
}

export interface FontOption {
  key: string;
  name: string;
  fallback: string;
}

export interface TextSizeOption {
  key: string;
  /** 1pt = 1/72in, so a preview at S px/in draws this at `points / 72 * S`. */
  points: number;
}

/** Everything the editor would otherwise have had to restate from the model. */
export interface EditorOptions {
  designConfigVersion: number;
  cardSizes: string[];
  fonts: FontOption[];
  textSizes: TextSizeOption[];
  alignments: string[];
  lineHeight: number;
  textMaxLength: number;
  minZoom: number;
  maxZoom: number;
  maxPan: number;
  maxPhotos: number;
}

export interface HolidayCardPhoto {
  blobId: string;
  filename: string;
  contentType: string | null;
  byteSize: number;
  url: string | null;
}

export interface HolidayCard {
  id: string;
  externalId: string;
  title: string | null;
  size: string;
  templateId: string;
  designConfig: DesignConfig | null;
  photos: HolidayCardPhoto[];
  updatedAt: string;
}

/**
 * Whether the print partner is configured, asked before the send flow is
 * offered rather than discovered at the charge step (#153).
 *
 * Two booleans because they read two different keys — proofs run against
 * PostGrid's test mode and mailing against live — so a deploy can genuinely
 * have one and not the other. A send needs both: nothing can be mailed without
 * an approved proof.
 */
export interface MailingAvailability {
  proofsAvailable: boolean;
  mailingAvailable: boolean;
}

/** Both halves configured, i.e. a send could actually run start to finish. */
export function canSendByPost(availability: MailingAvailability | null | undefined): boolean {
  return Boolean(availability?.proofsAvailable && availability?.mailingAvailable);
}

/** Counts behind the dashboard's "40 mailed · 2 failed". Never null; zeroed instead. */
export interface OrderSummary {
  /** Orders placed. `total - failed` is what actually went into the post. */
  total: number;
  inFlight: number;
  delivered: number;
  /** Failed or cancelled — every one of these was refunded. */
  failed: number;
  lastOrderedAt: string | null;
}

// ------------------------------------------------------------------ document

/** One photo placed in a slot. Pan is a fraction of the slot; zoom is a multiplier. */
export interface PhotoPlacement {
  blob_id: string;
  pan_x?: number;
  pan_y?: number;
  zoom?: number;
}

/** What the user wrote in a text region, and anything they overrode about it. */
export interface TextPlacement {
  content?: string;
  font?: string;
  size?: string;
  align?: string;
  color?: string;
}

/**
 * A sticker dropped into one of the template's declared sticker regions. Not
 * free placement — `region_id` names a region the template declares.
 */
export interface StickerPlacement {
  region_id: string;
  sticker_id: string;
}

export interface PanelConfig {
  photos?: Record<string, PhotoPlacement>;
  texts?: Record<string, TextPlacement>;
  /** A list because order is paint order, and reordering it is a design change. */
  stickers?: StickerPlacement[];
}

export interface DesignConfig {
  version: number;
  front?: PanelConfig;
  back?: PanelConfig;
}
