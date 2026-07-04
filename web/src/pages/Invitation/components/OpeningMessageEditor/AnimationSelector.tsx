import type { AnimationPreset } from '@/types/openingMessage';
import { ANIMATION_LIST } from '@/config/openingMessage';
import { cn } from '@/lib/utils';
import { Label } from '@/components/ui/label';

interface AnimationSelectorProps {
  preset: AnimationPreset;
  durationMs: number;
  onPresetChange: (preset: AnimationPreset) => void;
  onDurationChange: (durationMs: number) => void;
}

export function AnimationSelector({
  preset,
  durationMs,
  onPresetChange,
  onDurationChange,
}: AnimationSelectorProps) {
  return (
    <div className="space-y-6">
      {/* Animation Preset */}
      <div className="space-y-3">
        <Label>Animation Style</Label>
        <div className="grid grid-cols-2 gap-2">
          {ANIMATION_LIST.map(anim => (
            <button
              key={anim.id}
              type="button"
              onClick={() => onPresetChange(anim.id)}
              className={cn(
                'p-3 rounded-lg border-2 transition-all text-left',
                preset === anim.id
                  ? 'border-purple-500 bg-purple-50'
                  : 'border-gray-200 hover:border-gray-300'
              )}
            >
              <div className="font-medium text-sm">{anim.name}</div>
              <div className="text-xs text-gray-500">{anim.description}</div>
            </button>
          ))}
        </div>
      </div>

      {/* Duration */}
      <div className="space-y-3">
        <Label>Animation Duration: {(durationMs / 1000).toFixed(1)}s</Label>
        <input
          type="range"
          value={durationMs}
          onChange={e => onDurationChange(Number(e.target.value))}
          min={800}
          max={3000}
          step={100}
          className="w-full h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer accent-purple-500"
        />
      </div>
    </div>
  );
}
