import React, { useState } from 'react';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { isMobile } from '@/lib/utils';
import { gql, useLazyQuery } from '@apollo/client';
import Cropper from 'react-easy-crop';
import getCroppedImg from '@/lib/crop-image';
import { Area } from 'react-easy-crop';
import { Sheet, SheetContent, SheetHeader, SheetTitle } from '@/components/ui/sheet';
import ImageWithSkeleton from '@/components/ImageWithSkeleton';
import { useAuth } from '@/contexts/AuthContext';

interface CoverImageDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSelectCover: (coverUrlOrBlob: string | Blob) => void;
}

const GET_COVER_STYLES = gql`
  query GetStyles($tag: String) {
    coverStyles: styles(kind: "cover", tag: $tag, limit: 20) {
      id
      name
      value
    }
  }
`;

type UnsplashImage = {
  id: string;
  urls: { small: string; regular: string };
  alt_description?: string;
  description?: string;
  user: { name: string; links: { html: string } };
  links: { download_location: string };
};

const UNSPLASH_ACCESS_KEY = import.meta.env.VITE_UNSPLASH_ACCESS_KEY;
const CoverImageDialog: React.FC<CoverImageDialogProps> = ({
  open,
  onOpenChange,
  onSelectCover,
}) => {
  const [tab, setTab] = useState('unsplash'); // Default to unsplash since it's always available
  const [gallerySearchInput, setGallerySearchInput] = useState('');
  const [file, setFile] = useState<File | null>(null);
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const [uploadError, setUploadError] = useState('');
  const [crop, setCrop] = useState({ x: 0, y: 0 });
  const [zoom, setZoom] = useState(1);
  const [croppedAreaPixels, setCroppedAreaPixels] = useState<Area | null>(null);
  const [uploading, setUploading] = useState(false);
  const [unsplashImages, setUnsplashImages] = useState<UnsplashImage[]>([]);
  const [unsplashLoading, setUnsplashLoading] = useState(false);
  const [unsplashSearchInput, setUnsplashSearchInput] = useState('');
  const mobile = isMobile();
  const fileInputRef = React.useRef<HTMLInputElement>(null);
  const { user } = useAuth();

  const [getGalleryImages, galleryImagesResult] = useLazyQuery(GET_COVER_STYLES);

  // Reset upload state when dialog closes
  React.useEffect(() => {
    if (!open) {
      setFile(null);
      setImagePreview(null);
      setUploadError('');
      setCrop({ x: 0, y: 0 });
      setZoom(1);
      setCroppedAreaPixels(null);
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  }, [open]);

  // Fetch Unsplash images
  const fetchUnsplashImages = async (query?: string) => {
    setUnsplashLoading(true);
    try {
      let url = `https://api.unsplash.com/photos?client_id=${UNSPLASH_ACCESS_KEY}&per_page=12`;
      if (query) {
        url = `https://api.unsplash.com/search/photos?client_id=${UNSPLASH_ACCESS_KEY}&per_page=12&query=${encodeURIComponent(query)}`;
      }
      const res = await fetch(url);
      const data = await res.json();
      if (query) {
        setUnsplashImages(data.results || []);
      } else {
        setUnsplashImages(data || []);
      }
    } finally {
      setUnsplashLoading(false);
    }
  };

  // Track Unsplash download as required by their guidelines
  const trackUnsplashDownload = async (downloadLocation: string) => {
    try {
      await fetch(downloadLocation, {
        method: 'GET',
        headers: {
          Authorization: `Client-ID ${UNSPLASH_ACCESS_KEY}`,
        },
      });
    } catch (error) {
      console.error('Failed to track Unsplash download:', error);
    }
  };

  // Handle Unsplash image selection with download tracking
  const handleUnsplashImageSelect = async (img: UnsplashImage) => {
    // Track the download as required by Unsplash guidelines
    await trackUnsplashDownload(img.links.download_location);

    // Proceed with selecting the image
    onSelectCover(img.urls.regular);
    onOpenChange(false);
  };

  // Fetch default images when Unsplash tab is selected
  React.useEffect(() => {
    if (tab === 'unsplash' && unsplashImages.length === 0 && !unsplashLoading) {
      fetchUnsplashImages();
    }
  }, [tab, unsplashImages.length, unsplashLoading]);

  // When switching to the gallery tab, trigger default gallery fetch if not already loaded
  React.useEffect(() => {
    if (tab === 'gallery' && open && !galleryImagesResult.called && !galleryImagesResult.loading) {
      getGalleryImages({ variables: { tag: '' } });
    }
  }, [tab, open, galleryImagesResult.called, galleryImagesResult.loading, getGalleryImages]);

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

  const handleCropAndSelect = async () => {
    if (!file || !imagePreview || !croppedAreaPixels) {
      setUploadError('Image or crop area missing');
      return;
    }
    setUploading(true);
    try {
      const croppedBlob = await getCroppedImg(imagePreview, croppedAreaPixels);
      onSelectCover(croppedBlob); // Pass the blob back to parent
      onOpenChange(false);
    } catch (err) {
      console.error('Crop error:', err);
      setUploadError('Failed to crop image');
    } finally {
      setUploading(false);
    }
  };

  const handleSearchGallery = (searchTerm: string) => {
    getGalleryImages({
      variables: { tag: searchTerm },
    });
  };

  const coverStyles: Array<{ id: string; name: string; value: string }> =
    galleryImagesResult.data?.coverStyles || [];
  const coverLoading = galleryImagesResult.loading;

  return (
    <>
      {!mobile ? (
        <Dialog open={open} onOpenChange={onOpenChange}>
          <DialogContent className="max-w-6xl w-full sm:w-[800px] md:w-[1000px] lg:w-[1200px] xl:w-[1400px] p-0 overflow-hidden h-[80vh] max-h-[600px] flex flex-col">
            <div className="p-6 flex-shrink-0">
              <DialogHeader>
                <DialogTitle>Add Cover Image</DialogTitle>
              </DialogHeader>
            </div>
            <div className="flex-1 overflow-hidden px-6 pb-6">
              <Tabs value={tab} onValueChange={setTab} className="h-full flex flex-col">
                <div className="flex-shrink-0">
                  <TabsList className="flex gap-2 w-full">
                    <TabsTrigger
                      value="gallery"
                      disabled={!user}
                      title={!user ? 'Sign in to access gallery' : ''}
                      className={!user ? 'opacity-50 cursor-not-allowed' : ''}
                    >
                      Gallery
                    </TabsTrigger>
                    <TabsTrigger
                      value="upload"
                      disabled={!user}
                      title={!user ? 'Sign in to upload images' : ''}
                      className={!user ? 'opacity-50 cursor-not-allowed' : ''}
                    >
                      Upload
                    </TabsTrigger>
                    <TabsTrigger value="unsplash">Unsplash</TabsTrigger>
                  </TabsList>
                </div>
                <div className="flex-1 overflow-hidden mt-4">
                  <TabsContent value="gallery" className="h-full overflow-hidden">
                    <div className="flex items-center mb-3 gap-2">
                      <Input
                        placeholder="Search covers by keyword..."
                        value={gallerySearchInput}
                        onChange={e => setGallerySearchInput(e.target.value)}
                        className="flex-1"
                      />
                      <Button
                        className="h-10 px-6"
                        onClick={() => handleSearchGallery(gallerySearchInput)}
                      >
                        Search
                      </Button>
                    </div>
                    {mobile ? (
                      <div className="flex flex-col gap-4 h-full overflow-y-auto">
                        {coverLoading ? (
                          <div className="text-center text-gray-400">Loading...</div>
                        ) : (
                          coverStyles.map(style => (
                            <ImageWithSkeleton
                              key={style.id}
                              src={style.value}
                              alt={style.name}
                              onClick={() => onSelectCover(style.value)}
                              className="w-full aspect-[4/3] rounded-lg overflow-hidden border-2 border-transparent hover:border-gray-300 transition group"
                              style={{ maxHeight: 220 }}
                            />
                          ))
                        )}
                      </div>
                    ) : (
                      <div
                        className="h-full overflow-y-auto pb-16"
                        style={{
                          display: 'grid',
                          gridTemplateColumns: 'repeat(2, 1fr)',
                          gap: '1rem',
                          gridAutoRows: 'max-content',
                          alignContent: 'start',
                        }}
                      >
                        {coverLoading ? (
                          <div className="col-span-2 text-center text-gray-400">Loading...</div>
                        ) : (
                          coverStyles.map(style => (
                            <ImageWithSkeleton
                              key={style.id}
                              src={style.value}
                              alt={style.name}
                              onClick={() => onSelectCover(style.value)}
                              className="rounded-lg overflow-hidden border-2 border-transparent hover:border-gray-300 transition group"
                              style={{ aspectRatio: '4/3' }}
                            />
                          ))
                        )}
                      </div>
                    )}
                  </TabsContent>
                  <TabsContent value="upload" className="h-full overflow-hidden">
                    <div className="flex flex-col items-center justify-center h-full">
                      {!imagePreview ? (
                        <>
                          <input
                            ref={fileInputRef}
                            type="file"
                            accept="image/png, image/jpeg"
                            style={{ display: 'none' }}
                            onChange={handleUploadFileChange}
                          />
                          <Button
                            variant="outline"
                            onClick={() => fileInputRef.current?.click()}
                            className="mb-4 w-40"
                          >
                            Upload File
                          </Button>
                          {uploadError && (
                            <p className="text-sm text-red-500 mt-2">{uploadError}</p>
                          )}
                        </>
                      ) : (
                        <>
                          <div className="relative w-full max-w-md h-[300px] bg-black rounded-md overflow-hidden mb-4">
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
                          <div className="flex gap-2 w-full justify-center">
                            <Button
                              variant="outline"
                              onClick={() => {
                                setFile(null);
                                setImagePreview(null);
                                setUploadError('');
                                if (fileInputRef.current) fileInputRef.current.value = '';
                              }}
                            >
                              Cancel
                            </Button>
                            <Button
                              onClick={handleCropAndSelect}
                              disabled={uploading}
                              className="bg-black text-white"
                            >
                              {uploading ? 'Processing...' : 'Crop & Use Image'}
                            </Button>
                          </div>
                          {uploadError && (
                            <p className="text-sm text-red-500 mt-2">{uploadError}</p>
                          )}
                        </>
                      )}
                    </div>
                  </TabsContent>
                  <TabsContent value="unsplash" className="h-full overflow-hidden">
                    <div className="flex items-center mb-4 gap-2">
                      <Input
                        className="flex-1 h-12 text-base px-4"
                        placeholder="Search Unsplash images..."
                        value={unsplashSearchInput}
                        onChange={e => setUnsplashSearchInput(e.target.value)}
                      />
                      <Button
                        className="h-12 px-6"
                        onClick={() => fetchUnsplashImages(unsplashSearchInput)}
                        disabled={unsplashLoading}
                      >
                        Search
                      </Button>
                    </div>
                    {mobile ? (
                      <div className="flex flex-col gap-4 h-full overflow-y-auto pb-8">
                        {unsplashLoading ? (
                          <div className="text-center text-gray-400">Loading...</div>
                        ) : (
                          unsplashImages.map(img => (
                            <button
                              key={img.id}
                              onClick={() => handleUnsplashImageSelect(img)}
                              className="relative w-full aspect-[4/3] rounded-lg overflow-hidden border-2 border-transparent hover:border-gray-300 transition group"
                            >
                              <img
                                src={img.urls.regular}
                                alt={img.alt_description || img.description || 'Unsplash image'}
                                className="w-full h-full object-cover"
                                style={{ maxHeight: 220 }}
                              />
                              <div className="absolute bottom-6 right-2 bg-black/70 text-white text-xs px-2 py-1 rounded opacity-90 group-hover:opacity-100 pointer-events-none">
                                Photo by{' '}
                                <a
                                  href={`${img.user.links.html}?utm_source=CardJoy&utm_medium=referral`}
                                  target="_blank"
                                  rel="noopener noreferrer"
                                  className="underline pointer-events-auto"
                                >
                                  {img.user.name}
                                </a>{' '}
                                on{' '}
                                <a
                                  href="https://unsplash.com?utm_source=CardJoy&utm_medium=referral"
                                  target="_blank"
                                  rel="noopener noreferrer"
                                  className="underline pointer-events-auto"
                                >
                                  Unsplash
                                </a>
                              </div>
                            </button>
                          ))
                        )}
                      </div>
                    ) : (
                      <div
                        className="h-full overflow-y-auto pb-16"
                        style={{
                          display: 'grid',
                          gridTemplateColumns: 'repeat(2, 1fr)',
                          gap: '1rem',
                          gridAutoRows: 'max-content',
                          alignContent: 'start',
                        }}
                      >
                        {unsplashLoading ? (
                          <div className="col-span-2 text-center text-gray-400">Loading...</div>
                        ) : (
                          unsplashImages.map(img => (
                            <ImageWithSkeleton
                              key={img.id}
                              src={img.urls.small || img.urls.regular}
                              alt={img.alt_description || img.description || 'Unsplash image'}
                              onClick={() => handleUnsplashImageSelect(img)}
                              className="rounded-lg overflow-hidden border-2 border-transparent hover:border-gray-300 transition group"
                              style={{ aspectRatio: '4/3' }}
                            >
                              <div className="absolute bottom-2 right-2 bg-black/70 text-white text-xs px-2 py-1 rounded opacity-90 group-hover:opacity-100 pointer-events-none">
                                Photo by{' '}
                                <a
                                  href={`${img.user.links.html}?utm_source=CardJoy&utm_medium=referral`}
                                  target="_blank"
                                  rel="noopener noreferrer"
                                  className="underline pointer-events-auto"
                                >
                                  {img.user.name}
                                </a>{' '}
                                on{' '}
                                <a
                                  href="https://unsplash.com?utm_source=CardJoy&utm_medium=referral"
                                  target="_blank"
                                  rel="noopener noreferrer"
                                  className="underline pointer-events-auto"
                                >
                                  Unsplash
                                </a>
                              </div>
                            </ImageWithSkeleton>
                          ))
                        )}
                      </div>
                    )}
                  </TabsContent>
                </div>
              </Tabs>
            </div>
          </DialogContent>
        </Dialog>
      ) : (
        open && (
          <Sheet open={open} onOpenChange={onOpenChange}>
            <SheetContent
              side="right"
              className="w-full sm:w-[500px] h-full overflow-y-auto p-6 pb-24 animate-fade-in"
            >
              <SheetHeader>
                <SheetTitle className="font-semibold text-lg">Add Cover Image</SheetTitle>
              </SheetHeader>
              <Tabs value={tab} onValueChange={setTab} className="mt-2">
                <TabsList className="flex gap-2 w-full">
                  <TabsTrigger
                    value="gallery"
                    disabled={!user}
                    title={!user ? 'Sign in to access gallery' : ''}
                    className={!user ? 'opacity-50 cursor-not-allowed' : ''}
                  >
                    Gallery
                  </TabsTrigger>
                  <TabsTrigger
                    value="upload"
                    disabled={!user}
                    title={!user ? 'Sign in to upload images' : ''}
                    className={!user ? 'opacity-50 cursor-not-allowed' : ''}
                  >
                    Upload
                  </TabsTrigger>
                  <TabsTrigger value="unsplash">Unsplash</TabsTrigger>
                </TabsList>
                <div className="mt-4">
                  <TabsContent value="gallery">
                    <div className="flex items-center mb-3 gap-2">
                      <Input
                        placeholder="Search covers by keyword..."
                        value={gallerySearchInput}
                        onChange={e => setGallerySearchInput(e.target.value)}
                        className="flex-1"
                      />
                      <Button
                        className="h-10 px-6"
                        onClick={() => handleSearchGallery(gallerySearchInput)}
                      >
                        Search
                      </Button>
                    </div>
                    <div className="flex flex-col gap-4 pb-24">
                      {coverLoading ? (
                        <div className="text-center text-gray-400">Loading...</div>
                      ) : (
                        coverStyles.map(style => (
                          <ImageWithSkeleton
                            key={style.id}
                            src={style.value}
                            alt={style.name}
                            onClick={() => onSelectCover(style.value)}
                            className="w-full aspect-[4/3] rounded-lg overflow-hidden border-2 border-transparent hover:border-gray-300 transition group"
                            style={{ maxHeight: 220 }}
                          />
                        ))
                      )}
                    </div>
                  </TabsContent>
                  <TabsContent value="upload">
                    <div className="flex flex-col items-center justify-center min-h-[20rem]">
                      {!imagePreview ? (
                        <>
                          <input
                            ref={fileInputRef}
                            type="file"
                            accept="image/png, image/jpeg"
                            style={{ display: 'none' }}
                            onChange={handleUploadFileChange}
                          />
                          <Button
                            variant="outline"
                            onClick={() => fileInputRef.current?.click()}
                            className="mb-4 w-40"
                          >
                            Upload File
                          </Button>
                          {uploadError && (
                            <p className="text-sm text-red-500 mt-2">{uploadError}</p>
                          )}
                        </>
                      ) : (
                        <>
                          <div className="relative w-full max-w-md h-[300px] bg-black rounded-md overflow-hidden mb-4">
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
                          <div className="flex gap-2 w-full justify-center">
                            <Button
                              variant="outline"
                              onClick={() => {
                                setFile(null);
                                setImagePreview(null);
                                setUploadError('');
                                if (fileInputRef.current) fileInputRef.current.value = '';
                              }}
                            >
                              Cancel
                            </Button>
                            <Button
                              onClick={handleCropAndSelect}
                              disabled={uploading}
                              className="bg-black text-white"
                            >
                              {uploading ? 'Processing...' : 'Crop & Use Image'}
                            </Button>
                          </div>
                          {uploadError && (
                            <p className="text-sm text-red-500 mt-2">{uploadError}</p>
                          )}
                        </>
                      )}
                    </div>
                  </TabsContent>
                  <TabsContent value="unsplash">
                    <div className="flex items-center mb-4 gap-2">
                      <Input
                        className="flex-1 h-12 text-base px-4"
                        placeholder="Search Unsplash images..."
                        value={unsplashSearchInput}
                        onChange={e => setUnsplashSearchInput(e.target.value)}
                      />
                      <Button
                        className="h-12 px-6"
                        onClick={() => fetchUnsplashImages(unsplashSearchInput)}
                        disabled={unsplashLoading}
                      >
                        Search
                      </Button>
                    </div>
                    <div className="flex flex-col gap-4 pb-24">
                      {unsplashLoading ? (
                        <div className="text-center text-gray-400">Loading...</div>
                      ) : (
                        unsplashImages.map(img => (
                          <ImageWithSkeleton
                            key={img.id}
                            src={img.urls.regular}
                            alt={img.alt_description || img.description || 'Unsplash image'}
                            onClick={() => handleUnsplashImageSelect(img)}
                            className="w-full aspect-[4/3] rounded-lg overflow-hidden border-2 border-transparent hover:border-gray-300 transition group"
                            style={{ maxHeight: 220 }}
                          >
                            <div className="absolute bottom-6 right-2 bg-black/70 text-white text-xs px-2 py-1 rounded opacity-90 group-hover:opacity-100 pointer-events-none">
                              Photo by{' '}
                              <a
                                href={`${img.user.links.html}?utm_source=CardJoy&utm_medium=referral`}
                                target="_blank"
                                rel="noopener noreferrer"
                                className="underline pointer-events-auto"
                              >
                                {img.user.name}
                              </a>{' '}
                              on{' '}
                              <a
                                href="https://unsplash.com?utm_source=CardJoy&utm_medium=referral"
                                target="_blank"
                                rel="noopener noreferrer"
                                className="underline pointer-events-auto"
                              >
                                Unsplash
                              </a>
                            </div>
                          </ImageWithSkeleton>
                        ))
                      )}
                    </div>
                  </TabsContent>
                </div>
              </Tabs>
            </SheetContent>
          </Sheet>
        )
      )}
    </>
  );
};

export default CoverImageDialog;
