/**
 * The card's uploaded photos, and the way new ones get on.
 *
 * Photos belong to the *card*, not to a slot: `design_config` points a slot at a
 * blob id, so the same picture can appear in two slots and a photo can be
 * uploaded before anyone decides where it goes. That is why this is a library
 * rather than a per-slot file input.
 *
 * Uploads bypass Apollo. `apollo-upload-client` is not a dependency here, so
 * file-carrying mutations go through `uploadGraphQLMutation`'s multipart request
 * — the transport `apollo_upload_server` expects on the API.
 */
import React, { useRef, useState } from 'react';
import { ImagePlus, Loader2, Trash2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { uploadGraphQLMutation } from '@/lib/graphql-upload';
import { validateImageContents } from '@/lib/image-upload';
import { UPLOAD_HOLIDAY_CARD_PHOTO } from '../queries';
import type { EditorOptions, HolidayCardPhoto } from '../types';

/** Mirrors the model's own `content_type` and `size` validations. */
const ALLOWED_TYPES = ['image/png', 'image/jpeg', 'image/jpg', 'image/gif'];
const MAX_BYTES = 10 * 1024 * 1024;

interface PhotoLibraryProps {
  externalId: string;
  photos: HolidayCardPhoto[];
  options: EditorOptions;
  /** The slot waiting for a photo, if the user got here by clicking one. */
  targetSlotId: string | null;
  onPlace: (blobId: string) => void;
  onUploaded: (photo: HolidayCardPhoto) => void;
  onDelete: (blobId: string) => void;
  deletingBlobId?: string | null;
}

interface UploadResponse {
  uploadHolidayCardPhoto: {
    photo: HolidayCardPhoto | null;
    errors: string[];
  };
}

export const PhotoLibrary: React.FC<PhotoLibraryProps> = ({
  externalId,
  photos,
  options,
  targetSlotId,
  onPlace,
  onUploaded,
  onDelete,
  deletingBlobId,
}) => {
  const inputRef = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const atCapacity = photos.length >= options.maxPhotos;

  const handleFiles = async (files: FileList | null) => {
    if (!files?.length) return;
    setError(null);

    // Checked client-side first so the common mistakes are named before a 10MB
    // round trip; the server enforces the same limits regardless.
    const queued = Array.from(files).slice(0, Math.max(0, options.maxPhotos - photos.length));
    if (queued.length < files.length) {
      setError(
        `A card holds at most ${options.maxPhotos} photos, so not all of those were uploaded.`
      );
    }

    setUploading(true);
    try {
      for (const file of queued) {
        if (!ALLOWED_TYPES.includes(file.type)) {
          setError('Photos must be PNG, JPG, or GIF images.');
          continue;
        }
        if (file.size > MAX_BYTES) {
          setError(`"${file.name}" is larger than 10MB.`);
          continue;
        }

        // What the file *is*, not what it is called. An iPhone HEIC saved as
        // .jpg reports `image/jpeg` above and passes, then fails the server's
        // byte-level check after the whole upload — so read the signature here
        // and say so now. See `lib/image-upload.ts`.
        const contentsError = await validateImageContents(file);
        if (contentsError) {
          setError(contentsError);
          continue;
        }

        const result = await uploadGraphQLMutation<UploadResponse>({
          query: UPLOAD_HOLIDAY_CARD_PHOTO,
          input: { externalId, photoFile: null },
          filePath: 'variables.input.photoFile',
          file,
          filename: file.name,
        });

        const payload = result.data?.uploadHolidayCardPhoto;
        if (payload?.errors?.length) {
          setError(payload.errors.join(' '));
          continue;
        }
        if (result.errors?.length) {
          setError(result.errors.map(e => e.message).join(' '));
          continue;
        }
        if (payload?.photo) {
          onUploaded(payload.photo);
          // Uploading straight into an empty slot is the common path — the user
          // clicked the slot to get here, so land the photo where they pointed.
          if (targetSlotId && queued.length === 1) onPlace(payload.photo.blobId);
        }
      }
    } catch {
      setError('That upload did not go through. Please try again.');
    } finally {
      setUploading(false);
      if (inputRef.current) inputRef.current.value = '';
    }
  };

  return (
    <div className="space-y-3">
      <input
        ref={inputRef}
        type="file"
        multiple
        accept="image/png, image/jpeg, image/gif"
        className="hidden"
        onChange={event => handleFiles(event.target.files)}
      />

      <Button
        type="button"
        variant="outline"
        className="w-full gap-2"
        disabled={uploading || atCapacity}
        onClick={() => inputRef.current?.click()}
      >
        {uploading ? (
          <Loader2 className="w-4 h-4 animate-spin" />
        ) : (
          <ImagePlus className="w-4 h-4" />
        )}
        {uploading ? 'Uploading…' : 'Upload photos'}
      </Button>

      {atCapacity && (
        <p className="text-xs text-gray-500">
          This card is holding its maximum of {options.maxPhotos} photos. Remove one to add another.
        </p>
      )}
      {error && <p className="text-sm text-red-600">{error}</p>}

      {photos.length > 0 && (
        <>
          <p className="text-xs text-gray-500">
            {targetSlotId
              ? 'Pick a photo for the selected slot.'
              : 'Select a slot on the card, then pick a photo.'}
          </p>
          <div className="grid grid-cols-3 gap-2">
            {photos.map(photo => (
              <div key={photo.blobId} className="group relative aspect-square">
                <button
                  type="button"
                  disabled={!targetSlotId}
                  onClick={() => onPlace(photo.blobId)}
                  title={targetSlotId ? `Use ${photo.filename}` : photo.filename}
                  className={`h-full w-full overflow-hidden rounded-md border-2 border-gray-200 transition-colors ${
                    targetSlotId
                      ? 'hover:border-[var(--color-brand-yellow)]'
                      : 'cursor-default opacity-90'
                  }`}
                >
                  {photo.url && (
                    <img
                      src={photo.url}
                      alt={photo.filename}
                      className="h-full w-full object-cover"
                    />
                  )}
                </button>
                <button
                  type="button"
                  onClick={() => onDelete(photo.blobId)}
                  disabled={deletingBlobId === photo.blobId}
                  title={`Remove ${photo.filename}`}
                  className="absolute right-1 top-1 rounded-full bg-black/60 p-1 text-white opacity-0 transition-opacity group-hover:opacity-100 focus:opacity-100"
                >
                  {deletingBlobId === photo.blobId ? (
                    <Loader2 className="w-3 h-3 animate-spin" />
                  ) : (
                    <Trash2 className="w-3 h-3" />
                  )}
                </button>
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  );
};
