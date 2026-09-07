/**
 * The screen half of the print contract.
 *
 * `HolidayCard::PrintRenderer` lays a card out by absolutely positioning every
 * slot at its catalogue coordinates in inches. This module does the same thing
 * at `scale` pixels per inch. Every function here has a counterpart in that
 * class, and the pairs have to stay in step — a preview that lays things out
 * "close enough" with flexbox is worse than no preview, because it teaches the
 * user to trust something that is not what gets printed.
 *
 * The correspondence, function by function:
 *
 *   boxStyle          <- PrintRenderer#box_style
 *   photoTransform    <- PrintRenderer#photo_transform
 *   textStyle         <- PrintRenderer#text_style
 *   defaultTextColor  <- PrintRenderer#default_text_color / #relative_luminance
 *
 * Nothing in here hardcodes a coordinate, a font list, or a point size: the
 * geometry arrives on the template and the type scale on `EditorOptions`.
 */
import type { CSSProperties } from 'react';
import type {
  EditorOptions,
  FontOption,
  PanelName,
  Rect,
  TextRegion,
  TextSizeOption,
} from './types';

/**
 * Below this, a photo prints as mush. 150 DPI is the usual floor for
 * photographic print — we warn rather than block, because some people will want
 * a grainy snapshot anyway and that is their call.
 */
export const MIN_PHOTO_DPI = 150;

/** PrintRenderer::LIGHT_TEXT / DARK_TEXT — the two fallbacks a template picks between. */
const LIGHT_TEXT = '#FFFFFF';
const DARK_TEXT = '#1A1A1A';

/**
 * Absolute placement for a rect, in pixels.
 *
 * The bleed offset is the subtle part and it mirrors the renderer exactly:
 * catalogue coordinates are measured from the top-left of the *trimmed* panel,
 * while the document is the trim grown by the bleed on every side, so the origin
 * shifts by one bleed and every position with it.
 */
export function boxStyle(rect: Rect, scale: number, bleed: number, radius?: number): CSSProperties {
  return {
    position: 'absolute',
    overflow: 'hidden',
    left: (rect.x + bleed) * scale,
    top: (rect.y + bleed) * scale,
    width: rect.w * scale,
    height: rect.h * scale,
    ...(radius && radius > 0 ? { borderRadius: radius * scale } : {}),
  };
}

/**
 * The CSS transform for a photo inside its slot, byte-for-byte the string the
 * print renderer emits.
 *
 * Translate-then-scale, so pan and zoom stay independent: the percentages
 * resolve against the *untransformed* slot box, so panning by 0.1 always means
 * "a tenth of a slot to the right", whatever the zoom.
 */
export function photoTransform(
  placement: { pan_x?: number; pan_y?: number; zoom?: number } | undefined,
  options: EditorOptions
): string {
  const zoom = clamp(numeric(placement?.zoom, 1), options.minZoom, options.maxZoom);
  const panX = clamp(numeric(placement?.pan_x, 0), -options.maxPan, options.maxPan);
  const panY = clamp(numeric(placement?.pan_y, 0), -options.maxPan, options.maxPan);

  return `translate(${panX * 100}%, ${panY * 100}%) scale(${zoom})`;
}

/** The `<img>` inside a slot. Cover-fitted, then transformed — as in the renderer. */
export function photoImageStyle(transform: string): CSSProperties {
  return {
    position: 'absolute',
    left: 0,
    top: 0,
    width: '100%',
    height: '100%',
    objectFit: 'cover',
    transform,
    transformOrigin: 'center center',
    // The preview lets the user drag the photo behind a fixed window; without
    // this the browser starts its own image drag instead.
    pointerEvents: 'none',
    userSelect: 'none',
  };
}

/**
 * How a text region renders, at screen scale.
 *
 * `points / 72` is the conversion that makes this honest: a point is a physical
 * unit like an inch, so the same number produces print pixels at print DPI and
 * screen pixels here. Everything else — line height, alignment, wrapping — is
 * copied from `PrintRenderer#text_style` because those are exactly the
 * properties that decide where a line breaks.
 */
export function textStyle(
  region: TextRegion,
  placement: { font?: string; size?: string; align?: string; color?: string } | undefined,
  panelBackground: string,
  scale: number,
  bleed: number,
  options: EditorOptions
): CSSProperties {
  const font = allowed(
    placement?.font,
    options.fonts.map(f => f.key),
    region.defaultFont
  );
  const size = allowed(
    placement?.size,
    options.textSizes.map(s => s.key),
    region.defaultSize
  );
  const align = allowed(placement?.align, options.alignments, region.align);
  const color = hexColor(placement?.color) ?? defaultTextColor(panelBackground);

  return {
    ...boxStyle(region.rect, scale, bleed),
    fontFamily: fontStack(font, options.fonts),
    fontSize: (pointsFor(size, options.textSizes) / 72) * scale,
    lineHeight: options.lineHeight,
    textAlign: align as CSSProperties['textAlign'],
    color,
    whiteSpace: 'pre-wrap',
    wordWrap: 'break-word',
  };
}

/**
 * The CSS family for a font key.
 *
 * The server names its embedded faces "CardJoy Playfair Display" so PostGrid's
 * renderer cannot resolve a system copy at different metrics. In the browser the
 * same family arrives from `@fontsource`, which registers it under its plain
 * name — the same font files either way, so the metrics match and the line
 * breaks land in the same places.
 */
export function fontStack(key: string, fonts: FontOption[]): string {
  const font = fonts.find(candidate => candidate.key === key);
  if (!font) return 'serif';

  return `'${font.name}', ${font.fallback}`;
}

/** Point size for a scale step, falling back the way the renderer does. */
export function pointsFor(key: string, sizes: TextSizeOption[]): number {
  return (
    sizes.find(size => size.key === key)?.points ??
    sizes.find(size => size.key === 'md')?.points ??
    12
  );
}

/**
 * The colour a text region takes when the design document gives it none. Picked
 * against the panel background so a template with a dark background does not
 * render black text on it.
 */
export function defaultTextColor(background: string): string {
  return relativeLuminance(hexColor(background) ?? '#FFFFFF') < 0.5 ? LIGHT_TEXT : DARK_TEXT;
}

/** Good enough to answer "is this background dark?" — not a WCAG implementation. */
function relativeLuminance(hex: string): number {
  const [r, g, b] = [1, 3, 5].map(offset => parseInt(hex.slice(offset, offset + 2), 16) / 255);
  return 0.299 * r + 0.587 * g + 0.114 * b;
}

/**
 * The effective print resolution of a photo in its slot.
 *
 * `object-fit: cover` scales the image so it covers the slot, then `zoom`
 * enlarges it further, so the printed image is spread over
 * `zoom / min(nw/sw, nh/sh)` inches per pixel — invert that and the DPI falls
 * out. Zooming in always costs resolution, which is why zoom divides.
 *
 * Returns null when the image's natural size isn't known yet, so a slot whose
 * photo has not loaded shows no warning rather than a wrong one.
 */
export function effectivePhotoDpi(
  naturalSize: { width: number; height: number } | undefined,
  slot: Rect,
  zoom: number
): number | null {
  if (!naturalSize || !naturalSize.width || !naturalSize.height) return null;
  if (slot.w <= 0 || slot.h <= 0 || zoom <= 0) return null;

  return Math.min(naturalSize.width / slot.w, naturalSize.height / slot.h) / zoom;
}

/**
 * Whether a rect lands in the region PostGrid prints the address into. Only the
 * back panel has one; the front is entirely the user's.
 *
 * Touching edges is not overlapping, matching `HolidayCardCatalogue::Rect#overlaps?`
 * — a region ending exactly where the reserved block begins is legal.
 */
export function overlapsReserved(panel: PanelName, rect: Rect, reserved: Rect): boolean {
  if (panel !== 'back') return false;

  return (
    rect.x < reserved.x + reserved.w &&
    rect.x + rect.w > reserved.x &&
    rect.y < reserved.y + reserved.h &&
    rect.y + rect.h > reserved.y
  );
}

/**
 * Pixels per inch for a panel that must fit inside `available`, capped so a wide
 * screen doesn't blow a 6" card up past the point of being useful.
 *
 * One factor for both axes — an honest preview cannot stretch one direction.
 */
export function fitScale(
  template: { widthInches: number; heightInches: number; bleedInches: number },
  available: { width: number; height: number },
  maxScale = 110
): number {
  const width = template.widthInches + template.bleedInches * 2;
  const height = template.heightInches + template.bleedInches * 2;
  if (width <= 0 || height <= 0) return maxScale;

  return Math.max(1, Math.min(available.width / width, available.height / height, maxScale));
}

function allowed(value: string | undefined, permitted: string[], fallback: string): string {
  return value && permitted.includes(value) ? value : fallback;
}

function hexColor(value: string | undefined | null): string | null {
  return typeof value === 'string' && /^#[0-9a-fA-F]{6}$/.test(value) ? value : null;
}

function numeric(value: number | undefined, fallback: number): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback;
}

export function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}
