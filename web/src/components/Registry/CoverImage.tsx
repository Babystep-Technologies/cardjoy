/**
 * Owner's cover image for a registry (#247): shown at the top of the guest page and in the share
 * preview. Uploads go straight to their own mutation, so they happen as soon as a file is picked
 * and don't wait for "Save registry".
 */
import React, { useRef, useState } from 'react';
import { gql, useMutation } from '@apollo/client';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { uploadGraphQLMutation } from '@/lib/graphql-upload';

const SET_COVER = `
  mutation SetRegistryCoverImage($input: SetRegistryCoverImageInput!) {
    setRegistryCoverImage(input: $input) {
      wishList { externalId coverImageUrl }
      errors
    }
  }
`;

const REMOVE_COVER = gql`
  mutation RemoveRegistryCoverImage($input: RemoveRegistryCoverImageInput!) {
    removeRegistryCoverImage(input: $input) {
      wishList {
        externalId
        coverImageUrl
      }
      errors
    }
  }
`;

const ACCEPTED = ['image/png', 'image/jpeg', 'image/gif', 'image/webp'];
const MAX_BYTES = 10 * 1024 * 1024;

interface Props {
  externalId: string;
  coverImageUrl?: string | null;
  onChange: () => void;
}

export const CoverImage: React.FC<Props> = ({ externalId, coverImageUrl, onChange }) => {
  const fileInput = useRef<HTMLInputElement>(null);
  const [busy, setBusy] = useState(false);
  const [removeCover] = useMutation(REMOVE_COVER);

  const pick = async (file: File | undefined) => {
    if (!file) return;
    if (!ACCEPTED.includes(file.type)) {
      toast.error('Choose a PNG, JPEG, GIF or WebP image');
      return;
    }
    if (file.size >= MAX_BYTES) {
      toast.error('That image is over 10MB');
      return;
    }

    setBusy(true);
    try {
      const result = await uploadGraphQLMutation<{
        setRegistryCoverImage: { errors: string[] };
      }>({
        query: SET_COVER,
        input: { registryExternalId: externalId, coverImageFile: null },
        filePath: 'variables.input.coverImageFile',
        file,
        filename: file.name,
      });
      const errors =
        result.data?.setRegistryCoverImage?.errors ?? result.errors?.map(e => e.message) ?? [];
      if (errors.length > 0) {
        toast.error(errors.join(', '));
        return;
      }
      toast.success('Cover image updated');
      onChange();
    } catch (e) {
      console.error('Failed to upload cover image', e);
      toast.error('Failed to upload the image. Please try again.');
    } finally {
      setBusy(false);
      if (fileInput.current) fileInput.current.value = '';
    }
  };

  const remove = async () => {
    setBusy(true);
    try {
      await removeCover({ variables: { input: { registryExternalId: externalId } } });
      onChange();
    } catch (e) {
      console.error('Failed to remove cover image', e);
      toast.error('Failed to remove the image.');
    } finally {
      setBusy(false);
    }
  };

  return (
    <Card className="mb-6">
      <CardHeader>
        <CardTitle>Cover image</CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        {coverImageUrl && (
          <img
            src={coverImageUrl}
            alt="Registry cover"
            className="max-h-48 w-full rounded-lg object-cover"
          />
        )}
        <p className="text-sm text-gray-500">
          Shown at the top of your registry and when the link is shared. PNG, JPEG, GIF or WebP, up
          to 10MB.
        </p>
        <div className="flex gap-2">
          <input
            ref={fileInput}
            type="file"
            accept={ACCEPTED.join(',')}
            className="hidden"
            aria-label="Choose cover image"
            onChange={e => pick(e.target.files?.[0])}
          />
          <Button
            type="button"
            variant="outline"
            size="sm"
            disabled={busy}
            onClick={() => fileInput.current?.click()}
          >
            {busy ? 'Working...' : coverImageUrl ? 'Change image' : 'Add an image'}
          </Button>
          {coverImageUrl && (
            <Button type="button" variant="ghost" size="sm" disabled={busy} onClick={remove}>
              Remove
            </Button>
          )}
        </div>
      </CardContent>
    </Card>
  );
};
