import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Button } from '@/components/ui/button';
import { RotateCcw } from 'lucide-react';
import type { OpeningMessageText, TextTransform } from '@/types/openingMessage';

interface TextEditorProps {
  value: OpeningMessageText;
  onChange: (text: OpeningMessageText) => void;
}

const DEFAULT_TEXT_TRANSFORM: TextTransform = {
  x: 50,
  y: 50,
  rotation: 0,
  scale: 1,
};

export function TextEditor({ value, onChange }: TextEditorProps) {
  const transform = value.transform || DEFAULT_TEXT_TRANSFORM;
  const hasCustomTransform =
    transform.x !== 50 || transform.y !== 50 || transform.rotation !== 0 || transform.scale !== 1;

  const handleResetTransform = () => {
    onChange({
      ...value,
      transform: DEFAULT_TEXT_TRANSFORM,
    });
  };

  return (
    <div className="space-y-4">
      <div className="space-y-2">
        <Label htmlFor="opening-title">Title *</Label>
        <Input
          id="opening-title"
          value={value.title}
          onChange={e => onChange({ ...value, title: e.target.value })}
          placeholder="You're Invited!"
          className="text-lg"
        />
      </div>
      <div className="space-y-2">
        <Label htmlFor="opening-subtitle">Subtitle (optional)</Label>
        <Input
          id="opening-subtitle"
          value={value.subtitle || ''}
          onChange={e => onChange({ ...value, subtitle: e.target.value || null })}
          placeholder="Join us for a celebration"
        />
      </div>

      {/* Text Position Info */}
      <div className="pt-4 border-t space-y-2">
        <div className="flex items-center justify-between">
          <Label className="text-sm font-medium text-gray-700">Text Position</Label>
          {hasCustomTransform && (
            <Button
              type="button"
              variant="ghost"
              size="sm"
              onClick={handleResetTransform}
              className="text-xs h-7 px-2"
            >
              <RotateCcw className="w-3 h-3 mr-1" />
              Reset
            </Button>
          )}
        </div>

        <p className="text-xs text-gray-500">
          Click the text in the preview to select it. Drag to move, use the rotate handle at top, or
          resize handle at bottom-right.
        </p>

        {hasCustomTransform && (
          <div className="text-xs text-gray-500 bg-gray-50 p-2 rounded">
            Position: {Math.round(transform.x)}%, {Math.round(transform.y)}% | Scale:{' '}
            {Math.round(transform.scale * 100)}% | Rotation: {Math.round(transform.rotation)}°
          </div>
        )}
      </div>
    </div>
  );
}
