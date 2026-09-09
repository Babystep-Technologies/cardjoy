/**
 * Client-side mirror of the server's image rules, so a bad file is rejected before it is uploaded
 * rather than after. The server stays the real gate — see
 * `api/app/models/concerns/has_attached_image.rb` and the `logo` validation on `Organization`.
 */

const ALLOWED_IMAGE_TYPES = ['image/png', 'image/jpeg', 'image/jpg', 'image/gif'];
const MAX_IMAGE_BYTES = 10 * 1024 * 1024;

/** The reason this file can't be uploaded, or null when it can. */
export function validateImageFile(file: File): string | null {
  if (!ALLOWED_IMAGE_TYPES.includes(file.type)) {
    return `${file.name} must be a PNG, JPG, or GIF.`;
  }

  if (file.size > MAX_IMAGE_BYTES) {
    return `${file.name} must be smaller than 10MB.`;
  }

  return null;
}

/**
 * What a file's leading bytes actually say it is, regardless of what it is
 * called.
 *
 * `File.type` is the browser's guess, and on macOS it comes largely from the
 * extension — so an iPhone HEIC saved as `photo.jpg` reports `image/jpeg` and
 * sails through any check that trusts it. The server does not trust it: its
 * content type validation sniffs the real bytes, so that file is rejected after
 * a full upload for a reason the extension gave no hint of.
 *
 * Reading the first 16 bytes here closes that gap. The server remains the real
 * gate; this exists so the common mistakes are named before someone waits out a
 * 10MB upload to hear about them.
 */
const SIGNATURE_BYTES = 16;

/** ISO base media brands that mean HEIC/HEIF rather than plain MP4. */
const HEIF_BRANDS = [
  'heic',
  'heix',
  'hevc',
  'hevx',
  'heim',
  'heis',
  'hevm',
  'hevs',
  'mif1',
  'msf1',
];

export async function detectImageSignature(file: Blob): Promise<string | null> {
  const header = new Uint8Array(await file.slice(0, SIGNATURE_BYTES).arrayBuffer());
  if (header.length < 12) return null;

  const ascii = (start: number, end: number) => String.fromCharCode(...header.slice(start, end));
  const startsWith = (...bytes: number[]) => bytes.every((b, i) => header[i] === b);

  if (startsWith(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a)) return 'image/png';
  if (startsWith(0xff, 0xd8, 0xff)) return 'image/jpeg';
  if (ascii(0, 6) === 'GIF87a' || ascii(0, 6) === 'GIF89a') return 'image/gif';
  if (ascii(0, 4) === 'RIFF' && ascii(8, 12) === 'WEBP') return 'image/webp';
  if (startsWith(0x42, 0x4d)) return 'image/bmp';
  if (startsWith(0x49, 0x49, 0x2a, 0x00) || startsWith(0x4d, 0x4d, 0x00, 0x2a)) return 'image/tiff';
  if (ascii(0, 4) === '%PDF') return 'application/pdf';

  // ISO base media: the brand at bytes 8-12 separates HEIC from AVIF and video.
  if (ascii(4, 8) === 'ftyp') {
    const brand = ascii(8, 12);
    if (HEIF_BRANDS.includes(brand)) return 'image/heic';
    if (brand === 'avif' || brand === 'avis') return 'image/avif';
  }

  return null;
}

/** Human-readable names, so a rejection can say what the file actually is. */
const FORMAT_NAMES: Record<string, string> = {
  'image/webp': 'a WebP image',
  'image/bmp': 'a BMP image',
  'image/tiff': 'a TIFF image',
  'image/avif': 'an AVIF image',
  'application/pdf': 'a PDF',
};

/**
 * The reason this file's *contents* can't be uploaded, or null when they can.
 *
 * An unrecognized signature is deliberately allowed through rather than
 * rejected: this list is not exhaustive, and the server does the authoritative
 * check. Being wrong here should cost a round trip, never a usable photo.
 */
export async function validateImageContents(file: File): Promise<string | null> {
  let detected: string | null;
  try {
    detected = await detectImageSignature(file);
  } catch {
    return null; // Unreadable here is the server's problem to report, not ours.
  }

  if (detected === null || ALLOWED_IMAGE_TYPES.includes(detected)) return null;

  if (detected === 'image/heic') {
    return (
      `"${file.name}" is in Apple's HEIC format, which we cannot print. On your iPhone, either ` +
      'set Settings › Camera › Formats to "Most Compatible", or export this photo as a JPG.'
    );
  }

  return `"${file.name}" is ${FORMAT_NAMES[detected] ?? `a ${detected} file`}, not a PNG, JPG, or GIF.`;
}
