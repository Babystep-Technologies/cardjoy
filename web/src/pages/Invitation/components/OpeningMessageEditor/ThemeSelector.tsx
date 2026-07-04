import type { OpeningMessageTheme } from '@/types/openingMessage';
import { FONT_LIST, TEXT_COLORS } from '@/config/openingMessage';
import { cn } from '@/lib/utils';
import { Label } from '@/components/ui/label';

interface ThemeSelectorProps {
  value: OpeningMessageTheme;
  onChange: (theme: OpeningMessageTheme) => void;
}

export function ThemeSelector({ value, onChange }: ThemeSelectorProps) {
  return (
    <div className="space-y-6">
      {/* Font Selector */}
      <div className="space-y-3">
        <Label>Font</Label>
        <div className="grid grid-cols-2 gap-2">
          {FONT_LIST.map(font => (
            <button
              key={font.id}
              type="button"
              onClick={() => onChange({ ...value, font: font.id })}
              className={cn(
                'p-3 rounded-lg border-2 transition-all text-left',
                value.font === font.id
                  ? 'border-purple-500 bg-purple-50'
                  : 'border-gray-200 hover:border-gray-300'
              )}
              style={{ fontFamily: font.fontFamily }}
            >
              <div className="text-base">{font.name}</div>
            </button>
          ))}
        </div>
      </div>

      {/* Text Color Selector */}
      <div className="space-y-3">
        <Label>Text Color</Label>
        <div className="flex flex-wrap gap-2">
          {TEXT_COLORS.map(color => (
            <button
              key={color.value}
              type="button"
              onClick={() => onChange({ ...value, text_color: color.value })}
              className={cn(
                'w-10 h-10 rounded-full border-2 transition-all',
                value.text_color === color.value
                  ? 'ring-2 ring-purple-500 ring-offset-2'
                  : 'hover:scale-110'
              )}
              style={{ backgroundColor: color.value }}
              title={color.name}
            />
          ))}
        </div>
      </div>
    </div>
  );
}
