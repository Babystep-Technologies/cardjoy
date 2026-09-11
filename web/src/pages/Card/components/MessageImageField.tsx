import React, { useState } from 'react';
import { Area } from 'react-easy-crop';
import { ImagePlus, Sparkles, X } from 'lucide-react';
import { Button } from '@/components/ui/button';
import ImageUploaderWithGiphy from './ImageUploaderWithGiphy';

interface MessageImageFieldProps {
  imagePreview: string | null;
  setImageFile: (file: File | null) => void;
  setImageUrl: (url: string | null) => void;
  setImagePreview: (url: string | null) => void;
  setCroppedAreaPixels: (area: Area | null) => void;
  uploadError: string;
  setUploadError: (msg: string) => void;
  crop: { x: number; y: number };
  setCrop: (crop: { x: number; y: number }) => void;
  zoom: number;
  setZoom: (z: number) => void;
}

// GIPHY is optional; don't advertise a GIF button that opens an empty grid.
const giphyEnabled = Boolean(import.meta.env.VITE_GIPHY_API_KEY);

/**
 * The photo/GIF affordance for a card message. It sits directly under the message
 * textarea rather than up in the card header, and leads with the invitation instead
 * of a bare button, so signers actually notice the option exists.
 */
const MessageImageField: React.FC<MessageImageFieldProps> = ({
  imagePreview,
  setImageFile,
  setImageUrl,
  setImagePreview,
  setCroppedAreaPixels,
  uploadError,
  setUploadError,
  crop,
  setCrop,
  zoom,
  setZoom,
}) => {
  const [showUploader, setShowUploader] = useState(false);
  const [initialTab, setInitialTab] = useState<'giphy' | 'upload'>('upload');

  const openPicker = (tab: 'giphy' | 'upload') => {
    setInitialTab(tab);
    setShowUploader(true);
  };

  const clearImage = () => {
    setImageFile(null);
    setImageUrl(null);
    setImagePreview(null);
    setCroppedAreaPixels(null);
    setUploadError('');
  };

  return (
    <div>
      {imagePreview ? (
        <div className="space-y-2">
          <div className="relative w-full sm:w-64">
            <img
              src={imagePreview}
              alt="Attached to your message"
              className="w-full aspect-[3/2] object-cover rounded-lg border"
            />
            <button
              type="button"
              className="absolute top-2 right-2 z-10 bg-white rounded-full p-1 shadow hover:bg-gray-100"
              onClick={clearImage}
              aria-label="Remove image"
            >
              <X className="w-5 h-5 text-gray-800" />
            </button>
          </div>
          <Button
            type="button"
            variant="ghost"
            size="sm"
            className="px-2 text-purple-700 hover:text-purple-800 hover:bg-purple-50"
            onClick={() => openPicker('upload')}
          >
            <ImagePlus className="w-4 h-4" />
            Change image
          </Button>
        </div>
      ) : (
        <div className="rounded-xl border-2 border-dashed border-purple-200 bg-purple-50/50 p-4">
          <p className="text-sm font-semibold text-gray-800 flex items-center gap-2">
            <ImagePlus className="w-4 h-4 text-purple-600" />
            Make it pop — add a photo or GIF
          </p>
          <p className="mt-1 text-xs text-gray-600">
            Messages with a picture stand out on the card.
          </p>
          <div className="mt-3 flex flex-col sm:flex-row gap-2">
            <Button
              type="button"
              variant="outline"
              className="border-2 border-purple-300 bg-white font-semibold hover:border-purple-400 hover:bg-purple-50"
              onClick={() => openPicker('upload')}
            >
              <ImagePlus className="w-4 h-4" />
              Upload a photo
            </Button>
            {giphyEnabled && (
              <Button
                type="button"
                variant="outline"
                className="border-2 border-blue-300 bg-white font-semibold hover:border-blue-400 hover:bg-blue-50"
                onClick={() => openPicker('giphy')}
              >
                <Sparkles className="w-4 h-4" />
                Pick a GIF
              </Button>
            )}
          </div>
        </div>
      )}

      <ImageUploaderWithGiphy
        imagePreview={imagePreview}
        setImageFile={setImageFile}
        setImageUrl={setImageUrl}
        setImagePreview={setImagePreview}
        setCroppedAreaPixels={setCroppedAreaPixels}
        uploadError={uploadError}
        setUploadError={setUploadError}
        crop={crop}
        setCrop={setCrop}
        zoom={zoom}
        setZoom={setZoom}
        showSheet={showUploader}
        setShowSheet={setShowUploader}
        initialTab={initialTab}
      />
    </div>
  );
};

export default MessageImageField;
