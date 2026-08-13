import React, { useRef, useState } from 'react';
import { gql, useMutation, useQuery } from '@apollo/client';
import { ImagePlus, LoaderCircle, Trash2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { uploadGraphQLMutation } from '@/lib/graphql-upload';
import { validateImageFile } from '@/lib/image-upload';

/**
 * The organization's own cover artwork (#124): what its members see in the cover picker on top of
 * CardJoy's curated gallery. Admins add and retire it here; members see the grid read-only.
 */

const ORGANIZATION_ASSETS = gql`
  query OrganizationDesignAssets($organizationId: ID) {
    styles(kind: "cover", organizationId: $organizationId, limit: 200) {
      id
      name
      value
      organizationId
    }
  }
`;

const CREATE_ORGANIZATION_STYLE_DOCUMENT = `
  mutation CreateOrganizationStyle($input: CreateOrganizationStyleInput!) {
    createOrganizationStyle(input: $input) {
      style {
        id
        name
        value
        organizationId
      }
      errors
    }
  }
`;

const ARCHIVE_ORGANIZATION_STYLE = gql`
  mutation ArchiveOrganizationStyle($input: ArchiveOrganizationStyleInput!) {
    archiveOrganizationStyle(input: $input) {
      success
      errors
    }
  }
`;

type Style = {
  id: string;
  name: string;
  value: string | null;
  organizationId: string | null;
};

interface DesignAssetsProps {
  organizationId: string;
  canEdit: boolean;
  onErrors: (errors: string[]) => void;
  onSuccess: (message: string) => void;
}

const DesignAssets: React.FC<DesignAssetsProps> = ({
  organizationId,
  canEdit,
  onErrors,
  onSuccess,
}) => {
  const fileInput = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);
  const [archivingId, setArchivingId] = useState<string | null>(null);

  const { data, loading, refetch } = useQuery<{ styles: Style[] | null }>(ORGANIZATION_ASSETS, {
    variables: { organizationId },
    fetchPolicy: 'cache-and-network',
  });
  const [archiveStyle] = useMutation(ARCHIVE_ORGANIZATION_STYLE);

  // `styles` answers the cover picker's question — everything this context may choose from — so it
  // returns the global curated gallery alongside the organization's own. Only the latter belongs
  // here, and only an admin of this organization can change it.
  const assets = (data?.styles ?? []).filter(style => style.organizationId === organizationId);

  const handleUpload = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    // Let the same file be picked again after a failure — without this the input holds the old
    // value and `onChange` never fires a second time.
    event.target.value = '';
    if (!file) return;

    const validationError = validateImageFile(file);
    if (validationError) {
      onErrors([validationError]);
      return;
    }

    onErrors([]);
    setUploading(true);

    try {
      const json = await uploadGraphQLMutation<{
        createOrganizationStyle: { style: Style | null; errors: string[] };
      }>({
        query: CREATE_ORGANIZATION_STYLE_DOCUMENT,
        input: { organizationId, image: null, name: file.name },
        filePath: 'variables.input.image',
        file,
        filename: file.name,
      });

      const errors = json.errors?.length
        ? json.errors.map(error => error.message)
        : (json.data?.createOrganizationStyle.errors ?? []);

      if (errors.length > 0 || !json.data?.createOrganizationStyle.style) {
        onErrors(errors.length > 0 ? errors : ['Could not upload the design asset.']);
        return;
      }

      await refetch();
      onSuccess('Design asset uploaded.');
    } catch (error) {
      onErrors([error instanceof Error ? error.message : 'Could not upload the design asset.']);
    } finally {
      setUploading(false);
    }
  };

  const handleArchive = async (style: Style) => {
    onErrors([]);
    setArchivingId(style.id);

    try {
      const { data: result } = await archiveStyle({ variables: { input: { id: style.id } } });
      const errors: string[] = result?.archiveOrganizationStyle?.errors ?? [];

      if (errors.length > 0) {
        onErrors(errors);
        return;
      }

      await refetch();
      onSuccess(`Archived ${style.name}.`);
    } catch (error) {
      onErrors([error instanceof Error ? error.message : 'Could not archive the design asset.']);
    } finally {
      setArchivingId(null);
    }
  };

  return (
    <div className="space-y-4">
      {canEdit && (
        <div>
          <input
            ref={fileInput}
            type="file"
            accept="image/png, image/jpeg, image/jpg, image/gif"
            className="hidden"
            onChange={handleUpload}
          />
          <Button
            type="button"
            variant="outline"
            disabled={uploading}
            onClick={() => fileInput.current?.click()}
          >
            {uploading ? (
              <LoaderCircle className="h-4 w-4 animate-spin" />
            ) : (
              <ImagePlus className="h-4 w-4" />
            )}
            {uploading ? 'Uploading...' : 'Upload artwork'}
          </Button>
          <p className="mt-2 text-xs text-gray-500">PNG, JPG, or GIF • up to 10MB</p>
        </div>
      )}

      {loading && assets.length === 0 ? (
        <p className="text-sm text-gray-500">Loading artwork...</p>
      ) : assets.length === 0 ? (
        <p className="text-sm text-gray-500">
          No artwork yet.{' '}
          {canEdit
            ? 'Upload a cover image and it will appear in the picker for everyone here.'
            : 'An admin can upload cover images for everyone here to use.'}
        </p>
      ) : (
        <ul className="grid grid-cols-2 gap-4 sm:grid-cols-3">
          {assets.map(asset => (
            <li key={asset.id} className="group relative overflow-hidden rounded-lg border">
              <img
                src={asset.value ?? undefined}
                alt={asset.name}
                className="aspect-[4/3] w-full bg-gray-50 object-cover"
              />
              <p className="truncate px-2 py-1.5 text-xs text-gray-600" title={asset.name}>
                {asset.name}
              </p>
              {canEdit && (
                <button
                  type="button"
                  disabled={archivingId === asset.id}
                  onClick={() => handleArchive(asset)}
                  aria-label={`Archive ${asset.name}`}
                  className="absolute top-2 right-2 rounded-full bg-white/90 p-1.5 text-gray-600 shadow-sm transition hover:text-red-600 disabled:opacity-50"
                >
                  {archivingId === asset.id ? (
                    <LoaderCircle className="h-4 w-4 animate-spin" />
                  ) : (
                    <Trash2 className="h-4 w-4" />
                  )}
                </button>
              )}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
};

export default DesignAssets;
