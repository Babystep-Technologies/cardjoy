import { useState, useRef, useEffect } from 'react';
import { Sheet, SheetContent, SheetHeader, SheetTitle } from '@/components/ui/sheet';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { X, Loader2 } from 'lucide-react';
import Cropper from 'react-easy-crop';
import getCroppedImg from '@/lib/crop-image';
import { Area } from 'react-easy-crop';
import { toast } from 'sonner';
import { APP_TOKEN_KEY } from '@/lib/constants';

interface Props {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  availableTags: { id: string; name: string }[];
  refetchStyles: () => void;
}

const CreateCoverStyleSheet: React.FC<Props> = ({
  open,
  onOpenChange,
  availableTags,
  refetchStyles,
}) => {
  const [file, setFile] = useState<File | null>(null);
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const [uploadError, setUploadError] = useState('');
  const [newTags, setNewTags] = useState<string[]>([]);
  const [tagInput, setTagInput] = useState('');
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [crop, setCrop] = useState({ x: 0, y: 0 });
  const [zoom, setZoom] = useState(1);
  const [croppedAreaPixels, setCroppedAreaPixels] = useState<Area | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!open) {
      // reset all state when sheet is closed
      setFile(null);
      setImagePreview(null);
      setUploadError('');
      setNewTags([]);
      setTagInput('');
      setCrop({ x: 0, y: 0 });
      setZoom(1);
      setCroppedAreaPixels(null);
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  }, [open]);

  const handleUploadFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const selectedFile = e.target.files?.[0];
    if (!selectedFile) return;

    const allowedTypes = ['image/png', 'image/jpeg', 'image/jpg'];
    const maxSize = 10 * 1024 * 1024;

    if (!allowedTypes.includes(selectedFile.type)) {
      setUploadError('Only PNG, JPG, or JPEG files are allowed.');
      return;
    }
    if (selectedFile.size > maxSize) {
      setUploadError('File must be smaller than 10MB.');
      return;
    }

    setFile(selectedFile);
    setUploadError('');
    const reader = new FileReader();
    reader.onload = () => {
      setImagePreview(reader.result as string);
    };
    reader.readAsDataURL(selectedFile);
  };

  const handleUpload = async () => {
    try {
      if (!file || !imagePreview || !croppedAreaPixels) {
        toast.error('Image or crop area missing');
        return;
      }

      setLoading(true);

      const croppedBlob = await getCroppedImg(imagePreview, croppedAreaPixels);
      const croppedFile = new File([croppedBlob], file.name, { type: 'image/jpeg' });

      const formData = new FormData();

      formData.append(
        'operations',
        JSON.stringify({
          query: `
            mutation CreateCoverStyle($input: CreateCoverStyleInput!) {
              createCoverStyle(input: $input) {
                style {
                  id
                  name
                  value
                  tags {
                    id
                    name
                  }
                }
                errors
              }
            }
          `,
          variables: {
            input: {
              file: null,
              tagNames: newTags,
            },
          },
        })
      );

      formData.append('map', JSON.stringify({ '0': ['variables.input.file'] }));
      formData.append('0', croppedFile);

      const token = localStorage.getItem(APP_TOKEN_KEY);
      const res = await fetch(import.meta.env.VITE_GRAPHQL_ENDPOINT, {
        method: 'POST',
        body: formData,
        credentials: 'include',
        headers: {
          Authorization: token ? `Bearer ${token}` : '',
        },
      });

      const json = await res.json();

      if (json.errors || json.data.createCoverStyle.errors.length > 0) {
        toast.error(
          'Upload failed: ' +
            (json.errors?.[0]?.message ?? json.data.createCoverStyle.errors.join(', '))
        );
        return;
      }

      toast.success('Cover style uploaded successfully');
      refetchStyles();
      onOpenChange(false); // close the sheet
    } catch (err) {
      console.error(err);
      toast.error('Unexpected error uploading style');
    } finally {
      setLoading(false);
    }
  };

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="right" className="w-full sm:w-[500px] max-h-screen overflow-y-auto p-6">
        <SheetHeader>
          <SheetTitle>Upload Cover Style</SheetTitle>
        </SheetHeader>

        <div className="border border-dashed rounded-lg p-6 text-center">
          <Input
            ref={fileInputRef}
            type="file"
            accept="image/png, image/jpeg"
            onChange={handleUploadFileChange}
          />

          {file && <p className="mt-2 text-sm">{file.name}</p>}

          {imagePreview && (
            <div className="relative w-full h-[300px] bg-black rounded-md overflow-hidden mt-4">
              <button
                type="button"
                onClick={() => {
                  setFile(null);
                  setImagePreview(null);
                  setUploadError('');
                  if (fileInputRef.current) fileInputRef.current.value = '';
                }}
                className="absolute top-2 right-2 z-10 bg-white rounded-full p-1 shadow hover:bg-gray-100"
              >
                <X className="w-4 h-4 text-gray-800" />
              </button>
              <Cropper
                image={imagePreview}
                crop={crop}
                zoom={zoom}
                aspect={4 / 3}
                onCropChange={setCrop}
                onZoomChange={setZoom}
                onCropComplete={(_, area) => setCroppedAreaPixels(area)}
              />
            </div>
          )}

          {uploadError && <p className="text-sm text-red-500 mt-2">{uploadError}</p>}
        </div>

        <div className="space-y-2 mt-6">
          <p className="text-sm font-medium">Tags</p>
          <Input
            value={tagInput}
            onChange={e => setTagInput(e.target.value)}
            placeholder="Search or create tag..."
          />
          <div className="flex flex-wrap gap-2 mt-2">
            {newTags.map(tag => (
              <Badge
                key={tag}
                variant="secondary"
                className="cursor-pointer"
                onClick={() => setNewTags(newTags.filter(t => t !== tag))}
              >
                {tag} ✕
              </Badge>
            ))}
          </div>

          <div className="text-sm text-muted-foreground">
            {tagInput &&
              availableTags
                .filter(tag => tag.name.toLowerCase().includes(tagInput.toLowerCase()))
                .map(tag => (
                  <div
                    key={tag.id}
                    className="cursor-pointer px-2 py-1 hover:bg-gray-100 rounded"
                    onClick={() => {
                      if (!newTags.includes(tag.name)) setNewTags([...newTags, tag.name]);
                      setTagInput('');
                    }}
                  >
                    {tag.name}
                  </div>
                ))}
            {tagInput &&
              !availableTags.some(t => t.name.toLowerCase() === tagInput.toLowerCase()) && (
                <div
                  className="cursor-pointer px-2 py-1 hover:bg-gray-100 rounded text-blue-600"
                  onClick={() => {
                    const newTag = tagInput.toLowerCase();
                    if (!newTags.includes(newTag)) setNewTags([...newTags, newTag]);
                    setTagInput('');
                  }}
                >
                  Create new tag {`"${tagInput}"`}
                </div>
              )}
          </div>
        </div>

        <Button
          onClick={handleUpload}
          disabled={!file || newTags.length === 0 || loading}
          className="w-full bg-black text-white hover:bg-gray-900 mt-6"
        >
          {loading ? (
            <span className="flex items-center justify-center gap-2">
              <Loader2 className="w-4 h-4 animate-spin" />
              Uploading...
            </span>
          ) : (
            'Upload'
          )}
        </Button>
      </SheetContent>
    </Sheet>
  );
};

export default CreateCoverStyleSheet;
