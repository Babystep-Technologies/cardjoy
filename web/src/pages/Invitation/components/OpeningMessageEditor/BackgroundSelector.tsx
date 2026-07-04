import { useState, useRef } from 'react';
import type {
  OpeningMessageBackground,
  BackgroundType,
  ImageTransform,
} from '@/types/openingMessage';
import { GRADIENT_PRESETS, SOLID_COLORS } from '@/config/openingMessage';
import { cn } from '@/lib/utils';
import { Label } from '@/components/ui/label';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Upload, RotateCcw } from 'lucide-react';

interface BackgroundSelectorProps {
  value: OpeningMessageBackground;
  onChange: (background: OpeningMessageBackground) => void;
}

const DEFAULT_TRANSFORM: ImageTransform = {
  x: 0,
  y: 0,
  scale: 1,
  rotation: 0,
};

export function BackgroundSelector({ value, onChange }: BackgroundSelectorProps) {
  const [activeTab, setActiveTab] = useState<BackgroundType>(value.type);
  const [uploadError, setUploadError] = useState<string>('');
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleTabChange = (newType: string) => {
    // Only change the active tab UI, don't change the background until user selects something
    setActiveTab(newType as BackgroundType);
    setUploadError('');
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    // Validate file type
    const allowedTypes = ['image/png', 'image/jpeg', 'image/jpg'];
    if (!allowedTypes.includes(file.type)) {
      setUploadError('Only PNG, JPG, or JPEG files are allowed.');
      return;
    }

    // Validate file size (max 5MB)
    const maxSize = 5 * 1024 * 1024;
    if (file.size > maxSize) {
      setUploadError('File must be smaller than 5MB.');
      return;
    }

    setUploadError('');

    // Convert to data URL
    const reader = new FileReader();
    reader.onload = () => {
      onChange({
        ...value,
        type: 'image',
        value: reader.result as string,
        image_transform: value.image_transform || DEFAULT_TRANSFORM,
      });
    };
    reader.readAsDataURL(file);

    // Reset input so same file can be selected again
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  };

  const handleTransformChange = (updates: Partial<ImageTransform>) => {
    onChange({
      ...value,
      image_transform: {
        ...(value.image_transform || DEFAULT_TRANSFORM),
        ...updates,
      },
    });
  };

  const handleResetTransform = () => {
    onChange({
      ...value,
      image_transform: DEFAULT_TRANSFORM,
    });
  };

  const currentTransform = value.image_transform || DEFAULT_TRANSFORM;
  const hasImage = value.type === 'image' && value.value;

  return (
    <div className="space-y-4">
      <Label>Background</Label>
      <Tabs value={activeTab} onValueChange={handleTabChange}>
        <TabsList className="grid w-full grid-cols-3">
          <TabsTrigger value="gradient">Gradient</TabsTrigger>
          <TabsTrigger value="color">Color</TabsTrigger>
          <TabsTrigger value="image">Image</TabsTrigger>
        </TabsList>

        <TabsContent value="gradient" className="mt-4">
          <div className="grid grid-cols-4 gap-2">
            {GRADIENT_PRESETS.map(gradient => (
              <button
                key={gradient.id}
                type="button"
                onClick={() => onChange({ ...value, type: 'gradient', value: gradient.value })}
                className={cn(
                  'aspect-square rounded-lg border-2 transition-all',
                  value.type === 'gradient' && value.value === gradient.value
                    ? 'ring-2 ring-purple-500 ring-offset-2'
                    : 'hover:scale-105'
                )}
                style={{ background: gradient.preview }}
                title={gradient.name}
              />
            ))}
          </div>
        </TabsContent>

        <TabsContent value="color" className="mt-4">
          <div className="grid grid-cols-4 gap-2">
            {SOLID_COLORS.map(color => (
              <button
                key={color.id}
                type="button"
                onClick={() => onChange({ ...value, type: 'color', value: color.value })}
                className={cn(
                  'aspect-square rounded-lg border-2 transition-all',
                  value.type === 'color' && value.value === color.value
                    ? 'ring-2 ring-purple-500 ring-offset-2'
                    : 'hover:scale-105'
                )}
                style={{ backgroundColor: color.value }}
                title={color.name}
              />
            ))}
          </div>
        </TabsContent>

        <TabsContent value="image" className="mt-4 space-y-4">
          {/* File Upload */}
          <div className="space-y-2">
            <input
              ref={fileInputRef}
              type="file"
              accept="image/png, image/jpeg, image/jpg"
              className="hidden"
              onChange={handleFileChange}
            />
            <Button
              type="button"
              variant="outline"
              className="w-full gap-2"
              onClick={() => fileInputRef.current?.click()}
            >
              <Upload className="w-4 h-4" />
              Upload Image
            </Button>
            {uploadError && <p className="text-sm text-red-500">{uploadError}</p>}
          </div>

          {/* OR Divider */}
          <div className="relative">
            <div className="absolute inset-0 flex items-center">
              <span className="w-full border-t" />
            </div>
            <div className="relative flex justify-center text-xs uppercase">
              <span className="bg-white px-2 text-muted-foreground">or</span>
            </div>
          </div>

          {/* URL Input */}
          <div className="space-y-2">
            <Label htmlFor="bg-image-url">Image URL</Label>
            <Input
              id="bg-image-url"
              type="url"
              value={value.type === 'image' && !value.value.startsWith('data:') ? value.value : ''}
              onChange={e =>
                onChange({
                  ...value,
                  type: 'image',
                  value: e.target.value,
                  image_transform: value.image_transform || DEFAULT_TRANSFORM,
                })
              }
              placeholder="https://example.com/image.jpg"
            />
          </div>

          {/* Overlay Darkness */}
          <div className="space-y-2">
            <Label>Overlay Darkness: {Math.round((value.overlay_opacity || 0) * 100)}%</Label>
            <input
              type="range"
              value={(value.overlay_opacity || 0) * 100}
              onChange={e => onChange({ ...value, overlay_opacity: Number(e.target.value) / 100 })}
              min={0}
              max={80}
              step={5}
              className="w-full h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer accent-purple-500"
            />
          </div>

          {/* Image Transform Controls - only show when image is selected */}
          {hasImage && (
            <div className="space-y-4 pt-4 border-t">
              <div className="flex items-center justify-between">
                <Label className="text-sm font-medium">Image Adjustments</Label>
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  onClick={handleResetTransform}
                  className="h-8 gap-1 text-xs"
                >
                  <RotateCcw className="w-3 h-3" />
                  Reset
                </Button>
              </div>

              {/* Scale Slider */}
              <div className="space-y-2">
                <Label className="text-xs text-muted-foreground">
                  Scale: {Math.round(currentTransform.scale * 100)}%
                </Label>
                <input
                  type="range"
                  value={currentTransform.scale * 100}
                  onChange={e => handleTransformChange({ scale: Number(e.target.value) / 100 })}
                  min={50}
                  max={300}
                  step={5}
                  className="w-full h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer accent-purple-500"
                />
              </div>

              {/* Rotation Slider */}
              <div className="space-y-2">
                <Label className="text-xs text-muted-foreground">
                  Rotation: {currentTransform.rotation}°
                </Label>
                <input
                  type="range"
                  value={currentTransform.rotation}
                  onChange={e => handleTransformChange({ rotation: Number(e.target.value) })}
                  min={0}
                  max={360}
                  step={5}
                  className="w-full h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer accent-purple-500"
                />
              </div>

              {/* Drag Instructions */}
              <p className="text-xs text-muted-foreground text-center">
                Drag the preview to reposition the image
              </p>
            </div>
          )}
        </TabsContent>
      </Tabs>
    </div>
  );
}
