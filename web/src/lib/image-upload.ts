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
