import React, { useRef, useState } from 'react';
import { Input } from '@/components/ui/input';
import Cropper, { Area } from 'react-easy-crop';
import { Sheet, SheetContent, SheetHeader, SheetTitle } from '@/components/ui/sheet';
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs';
import { Dialog, DialogContent } from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import ImageWithSkeleton from '@/components/ImageWithSkeleton';

interface ImageUploaderProps {
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
  showSheet?: boolean;
  setShowSheet?: (open: boolean) => void;
}

interface GiphyGif {
  id: string;
  title: string;
  images: {
    original: { url: string };
    fixed_width: { url: string };
  };
}

const ImageUploaderWithGiphy: React.FC<ImageUploaderProps> = ({
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
  showSheet: showSheetProp,
  setShowSheet: setShowSheetProp,
}) => {
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const [internalShowSheet, internalSetShowSheet] = useState(false);
  const showSheet = showSheetProp !== undefined ? showSheetProp : internalShowSheet;
  const setShowSheet = setShowSheetProp !== undefined ? setShowSheetProp : internalSetShowSheet;
  const [tab, setTab] = useState<'giphy' | 'upload'>('giphy');
  const [giphySearch, setGiphySearch] = useState('');

  const [giphyResults, setGiphyResults] = useState<GiphyGif[]>([]);
  const [giphyLoading, setGiphyLoading] = useState(false);
  const [croppedAreaPixelsState, setCroppedAreaPixelsState] = useState<Area | null>(null);

  // Add local state for file and preview
  const [localImageFile, setLocalImageFile] = useState<File | null>(null);
  const [localImagePreview, setLocalImagePreview] = useState<string | null>(null);

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const allowedTypes = ['image/png', 'image/jpeg', 'image/jpg', 'image/gif'];
    const maxSize = 10 * 1024 * 1024; // 10MB to match backend

    if (!allowedTypes.includes(file.type)) {
      setUploadError('Only PNG, JPG, JPEG, or GIF files are allowed.');
      return;
    }

    if (file.size > maxSize) {
      setUploadError('File size must be less than 10MB. Please choose a smaller image.');
      return;
    }

    const reader = new FileReader();
    reader.onload = () => setLocalImagePreview(reader.result as string);
    reader.readAsDataURL(file);
    setLocalImageFile(file);
    setUploadError('');
  };

  const fetchGiphy = async (query: string) => {
    const apiKey = import.meta.env.VITE_GIPHY_API_KEY;
    if (!apiKey) {
      // GIPHY is optional — skip when no key is configured.
      setGiphyResults([]);
      setGiphyLoading(false);
      return;
    }
    setGiphyLoading(true);
    try {
      let url: string;
      if (query && query.trim() !== '') {
        url = `https://api.giphy.com/v1/gifs/search?api_key=${apiKey}&q=${encodeURIComponent(query)}&limit=12&rating=pg`;
      } else {
        url = `https://api.giphy.com/v1/gifs/trending?api_key=${apiKey}&limit=12&rating=pg`;
      }
      const res = await fetch(url);
      const data = await res.json();
      setGiphyResults(data.data || []);
    } finally {
      setGiphyLoading(false);
    }
  };

  const mobile = window.innerWidth <= 640; // Use window width to determine mobile

  // Utility to reset all local state related to search/cropper, but NOT parent image state
  const resetUploaderLocalState = React.useCallback(() => {
    setLocalImageFile(null);
    setLocalImagePreview(null);
    setCroppedAreaPixelsState(null);
    setTab('upload');
    setGiphySearch('');
    setGiphyResults([]);
    setGiphyLoading(false);
    if (fileInputRef.current) fileInputRef.current.value = '';
  }, []);

  // Clear state when dialog/sheet is closed
  React.useEffect(() => {
    if (!showSheet) {
      resetUploaderLocalState();
    }
  }, [showSheet, resetUploaderLocalState]);

  // Fetch trending GIPHY GIFs when GIPHY tab is loaded for the first time
  React.useEffect(() => {
    if (tab === 'giphy' && giphyResults.length === 0 && !giphyLoading) {
      fetchGiphy(''); // Empty string fetches trending GIFs
    }
  }, [tab, giphyResults.length, giphyLoading]);

  // Always default to GIPHY tab when the uploader is opened
  React.useEffect(() => {
    if (showSheet) {
      setTab('giphy');
    }
  }, [showSheet]);

  return (
    <>
      {!mobile ? (
        <Dialog open={showSheet} onOpenChange={setShowSheet}>
          <DialogContent className="max-w-2xl w-full p-0 overflow-hidden min-h-[28rem]">
            <div className="p-6 animate-fade-in" style={{ minHeight: '24rem' }}>
              <SheetHeader>
                <SheetTitle className="font-semibold text-lg">
                  {imagePreview ? 'Change Image' : 'Add Image'}
                </SheetTitle>
              </SheetHeader>
              <Tabs
                value={tab}
                onValueChange={v => setTab(v as 'giphy' | 'upload')}
                className="mt-2 flex-1"
              >
                <TabsList className="flex gap-2 w-full">
                  <TabsTrigger value="giphy">GIPHY</TabsTrigger>
                  <TabsTrigger value="upload">Upload</TabsTrigger>
                </TabsList>
                <div className="mt-4" style={{ minHeight: '20rem' }}>
                  <TabsContent value="upload">
                    <Input
                      type="file"
                      accept="image/png, image/jpeg, image/jpg, image/gif"
                      ref={fileInputRef}
                      onChange={handleFileChange}
                      className="mt-2 mb-2"
                    />
                    <p className="text-xs text-gray-500 mt-1 mb-3">
                      Supported formats: PNG, JPG, JPEG, GIF • Maximum size: 10MB
                    </p>
                    {localImagePreview && (
                      <>
                        <div className="relative w-full max-w-lg h-[266px] bg-black rounded-md overflow-hidden mt-2 mb-2">
                          {localImageFile && localImagePreview ? (
                            <Cropper
                              image={localImagePreview}
                              crop={crop}
                              zoom={zoom}
                              aspect={4 / 3}
                              onCropChange={setCrop}
                              onZoomChange={setZoom}
                              onCropComplete={(_, croppedPixels) => {
                                setCroppedAreaPixels(croppedPixels);
                                setCroppedAreaPixelsState(croppedPixels);
                              }}
                            />
                          ) : (
                            <img
                              src={localImagePreview ?? undefined}
                              alt="Selected"
                              className="w-full h-full object-cover"
                            />
                          )}
                        </div>
                        {localImageFile && localImagePreview && (
                          <div className="flex gap-2 w-full justify-center mt-4">
                            <button
                              type="button"
                              onClick={() => {
                                setLocalImageFile(null);
                                setLocalImagePreview(null);
                                setImageFile(null);
                                setImageUrl(null);
                                setImagePreview(null);
                                setCroppedAreaPixels(null);
                                setUploadError('');
                                if (fileInputRef.current) fileInputRef.current.value = '';
                              }}
                              className="px-4 py-2 rounded border border-gray-300 bg-white text-gray-700 hover:bg-gray-100"
                            >
                              Cancel
                            </button>
                            <button
                              type="button"
                              onClick={async () => {
                                if (!localImageFile || !localImagePreview || !crop) return;
                                if (!setImagePreview || !setImageFile) return;
                                if (!setImageUrl) return;
                                if (!setShowSheet) return;
                                if (!setCroppedAreaPixels) return;
                                if (!setUploadError) return;
                                if (!croppedAreaPixelsState) {
                                  setUploadError('Please crop the image.');
                                  return;
                                }
                                const getCroppedImg = (await import('@/lib/crop-image')).default;
                                const croppedBlob = await getCroppedImg(
                                  localImagePreview,
                                  croppedAreaPixelsState
                                );
                                const croppedUrl = URL.createObjectURL(croppedBlob);
                                setImagePreview(croppedUrl);
                                setImageFile(
                                  new File([croppedBlob], localImageFile.name, {
                                    type: 'image/jpeg',
                                  })
                                );
                                setImageUrl(null);
                                setShowSheet(false);
                                setLocalImageFile(null);
                                setLocalImagePreview(null);
                              }}
                              className="px-4 py-2 rounded bg-black text-white hover:bg-gray-900"
                            >
                              Crop Image
                            </button>
                          </div>
                        )}
                      </>
                    )}
                    {uploadError && <p className="text-sm text-red-500 mt-2">{uploadError}</p>}
                  </TabsContent>
                  <TabsContent value="giphy">
                    <div className="flex items-center mb-4 gap-2">
                      <Input
                        className="flex-1 h-12 text-base px-4"
                        placeholder="Search GIPHY GIFs..."
                        value={giphySearch}
                        onChange={e => setGiphySearch(e.target.value)}
                        onKeyDown={e => {
                          if (e.key === 'Enter') fetchGiphy(giphySearch);
                        }}
                      />
                      <Button
                        className="h-10 px-6"
                        onClick={() => fetchGiphy(giphySearch)}
                        disabled={giphyLoading}
                      >
                        Search
                      </Button>
                    </div>
                    <div className="grid grid-cols-3 gap-4">
                      {giphyLoading ? (
                        <div className="col-span-3 text-center text-gray-400">Loading...</div>
                      ) : (
                        giphyResults.map(gif => (
                          <ImageWithSkeleton
                            key={gif.id}
                            src={gif.images.fixed_width.url}
                            alt={gif.title || 'Giphy gif'}
                            onClick={() => {
                              setImageUrl(gif.images.original.url);
                              setImagePreview(gif.images.original.url);
                              setImageFile(null);
                              setShowSheet(false);
                            }}
                            className="aspect-[4/3] rounded-lg overflow-hidden border-2 border-transparent hover:border-gray-300 transition group"
                          />
                        ))
                      )}
                    </div>
                  </TabsContent>
                </div>
              </Tabs>
            </div>
          </DialogContent>
        </Dialog>
      ) : (
        <Sheet open={showSheet} onOpenChange={setShowSheet}>
          <SheetContent
            side="right"
            className="w-full sm:w-[500px] max-h-screen overflow-y-auto p-6 animate-fade-in"
          >
            <SheetHeader>
              <SheetTitle className="font-semibold text-lg">
                {imagePreview ? 'Change Image' : 'Add Image'}
              </SheetTitle>
            </SheetHeader>
            <Tabs
              value={tab}
              onValueChange={v => setTab(v as 'giphy' | 'upload')}
              className="mt-2 flex-1"
            >
              <TabsList className="flex gap-2 w-full">
                <TabsTrigger value="giphy">GIPHY</TabsTrigger>
                <TabsTrigger value="upload">Upload</TabsTrigger>
              </TabsList>
              <div className="mt-4" style={{ minHeight: '20rem' }}>
                <TabsContent value="upload">
                  <Input
                    type="file"
                    accept="image/png, image/jpeg, image/jpg, image/gif"
                    ref={fileInputRef}
                    onChange={handleFileChange}
                    className="mt-2 mb-2"
                  />
                  <p className="text-xs text-gray-500 mt-1 mb-3">
                    Supported formats: PNG, JPG, JPEG, GIF • Maximum size: 10MB
                  </p>
                  {localImagePreview && (
                    <>
                      <div className="relative w-full max-w-lg h-[266px] bg-black rounded-md overflow-hidden mt-2 mb-2">
                        {localImageFile && localImagePreview ? (
                          <Cropper
                            image={localImagePreview}
                            crop={crop}
                            zoom={zoom}
                            aspect={4 / 3}
                            onCropChange={setCrop}
                            onZoomChange={setZoom}
                            onCropComplete={(_, croppedPixels) => {
                              setCroppedAreaPixels(croppedPixels);
                              setCroppedAreaPixelsState(croppedPixels);
                            }}
                          />
                        ) : (
                          <img
                            src={localImagePreview ?? undefined}
                            alt="Selected"
                            className="w-full h-full object-cover"
                          />
                        )}
                      </div>
                      {localImageFile && localImagePreview && (
                        <div className="flex gap-2 w-full justify-center mt-4">
                          <button
                            type="button"
                            onClick={() => {
                              setLocalImageFile(null);
                              setLocalImagePreview(null);
                              setImageFile(null);
                              setImageUrl(null);
                              setImagePreview(null);
                              setCroppedAreaPixels(null);
                              setUploadError('');
                              if (fileInputRef.current) fileInputRef.current.value = '';
                            }}
                            className="px-4 py-2 rounded border border-gray-300 bg-white text-gray-700 hover:bg-gray-100"
                          >
                            Cancel
                          </button>
                          <button
                            type="button"
                            onClick={async () => {
                              if (!localImageFile || !localImagePreview || !crop) return;
                              if (!setImagePreview || !setImageFile) return;
                              if (!setImageUrl) return;
                              if (!setShowSheet) return;
                              if (!setCroppedAreaPixels) return;
                              if (!setUploadError) return;
                              if (!croppedAreaPixelsState) {
                                setUploadError('Please crop the image.');
                                return;
                              }
                              const getCroppedImg = (await import('@/lib/crop-image')).default;
                              const croppedBlob = await getCroppedImg(
                                localImagePreview,
                                croppedAreaPixelsState
                              );
                              const croppedUrl = URL.createObjectURL(croppedBlob);
                              setImagePreview(croppedUrl);
                              setImageFile(
                                new File([croppedBlob], localImageFile.name, {
                                  type: 'image/jpeg',
                                })
                              );
                              setImageUrl(null);
                              setShowSheet(false);
                              setLocalImageFile(null);
                              setLocalImagePreview(null);
                            }}
                            className="px-4 py-2 rounded bg-black text-white hover:bg-gray-900"
                          >
                            Crop Image
                          </button>
                        </div>
                      )}
                    </>
                  )}
                  {uploadError && <p className="text-sm text-red-500 mt-2">{uploadError}</p>}
                </TabsContent>
                <TabsContent value="giphy">
                  <div className="flex items-center mb-4 gap-2">
                    <Input
                      className="flex-1 h-12 text-base px-4"
                      placeholder="Search GIPHY GIFs..."
                      value={giphySearch}
                      onChange={e => setGiphySearch(e.target.value)}
                      onKeyDown={e => {
                        if (e.key === 'Enter') fetchGiphy(giphySearch);
                      }}
                    />
                    <Button
                      className="h-10 px-6"
                      onClick={() => fetchGiphy(giphySearch)}
                      disabled={giphyLoading}
                      type="button"
                    >
                      Search
                    </Button>
                  </div>
                  {mobile ? (
                    <div className="flex flex-col gap-4">
                      {giphyLoading ? (
                        <div className="text-center text-gray-400">Loading...</div>
                      ) : (
                        giphyResults.map(gif => (
                          <ImageWithSkeleton
                            key={gif.id}
                            src={gif.images.fixed_width.url}
                            alt={gif.title || 'Giphy gif'}
                            onClick={() => {
                              setImageUrl(gif.images.original.url);
                              setImagePreview(gif.images.original.url);
                              setImageFile(null);
                              setShowSheet(false);
                            }}
                            className="w-full aspect-[4/3] rounded-lg overflow-hidden border-2 border-transparent hover:border-gray-300 transition group"
                          />
                        ))
                      )}
                    </div>
                  ) : (
                    <div className="grid grid-cols-3 gap-4">
                      {giphyLoading ? (
                        <div className="col-span-3 text-center text-gray-400">Loading...</div>
                      ) : (
                        giphyResults.map(gif => (
                          <ImageWithSkeleton
                            key={gif.id}
                            src={gif.images.fixed_width.url}
                            alt={gif.title || 'Giphy gif'}
                            onClick={() => {
                              setImageUrl(gif.images.original.url);
                              setImagePreview(gif.images.original.url);
                              setImageFile(null);
                              setShowSheet(false);
                            }}
                            className="aspect-[4/3] rounded-lg overflow-hidden border-2 border-transparent hover:border-gray-300 transition group"
                          />
                        ))
                      )}
                    </div>
                  )}
                </TabsContent>
              </div>
            </Tabs>
          </SheetContent>
        </Sheet>
      )}
    </>
  );
};

export default ImageUploaderWithGiphy;
