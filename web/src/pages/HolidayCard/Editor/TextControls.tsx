/**
 * Font, size, alignment, and colour for the selected text region.
 *
 * Every list here comes from `holidayCardEditorOptions`. There is deliberately
 * no hardcoded font array: the model validates `font` against
 * `HolidayCard::VALID_FONTS` and the print renderer can only embed the faces it
 * has vendored, so a second list in TypeScript would eventually offer something
 * that either fails to save or prints in the wrong face.
 *
 * Each control writes only what the user changed. A region the user has not
 * touched keeps no font or size in the document at all, and inherits the
 * template's design intent — which means retouching a template's defaults still
 * reaches cards that never overrode them.
 */
import React from 'react';
import { Label } from '@/components/ui/label';
import { Button } from '@/components/ui/button';
import { AlignCenter, AlignLeft, AlignRight, RotateCcw } from 'lucide-react';
import { defaultTextColor, fontStack, pointsFor } from '../geometry';
import { setTextPlacement, textPlacement } from '../design';
import type { DesignConfig, EditorOptions, PanelName, TextRegion } from '../types';

const ALIGN_ICONS: Record<string, React.ComponentType<{ className?: string }>> = {
  left: AlignLeft,
  center: AlignCenter,
  right: AlignRight,
};

interface TextControlsProps {
  region: TextRegion;
  panel: PanelName;
  panelBackground: string;
  config: DesignConfig;
  options: EditorOptions;
  onChange: (next: DesignConfig) => void;
}

export const TextControls: React.FC<TextControlsProps> = ({
  region,
  panel,
  panelBackground,
  config,
  options,
  onChange,
}) => {
  const placement = textPlacement(config, panel, region.id) ?? {};
  const font = placement.font ?? region.defaultFont;
  const size = placement.size ?? region.defaultSize;
  const align = placement.align ?? region.align;
  const color = placement.color ?? defaultTextColor(panelBackground);

  const patch = (changes: Partial<typeof placement>) =>
    onChange(setTextPlacement(config, panel, region.id, { ...placement, ...changes }));

  const characters = placement.content?.length ?? 0;

  return (
    <div className="space-y-4">
      <div>
        <Label className="text-xs text-gray-600">Font</Label>
        <div className="mt-1.5 grid grid-cols-2 gap-1.5">
          {options.fonts.map(option => (
            <button
              key={option.key}
              type="button"
              onClick={() => patch({ font: option.key })}
              style={{ fontFamily: fontStack(option.key, options.fonts) }}
              className={`truncate rounded-md border px-2 py-1.5 text-sm transition-colors ${
                option.key === font
                  ? 'border-[var(--color-brand-yellow)] bg-amber-50'
                  : 'border-gray-200 hover:border-gray-400'
              }`}
            >
              {option.name}
            </button>
          ))}
        </div>
      </div>

      <div>
        <Label className="text-xs text-gray-600">Size</Label>
        <div className="mt-1.5 flex gap-1.5">
          {options.textSizes.map(option => (
            <button
              key={option.key}
              type="button"
              onClick={() => patch({ size: option.key })}
              title={`${option.points}pt`}
              className={`flex-1 rounded-md border py-1.5 text-xs uppercase transition-colors ${
                option.key === size
                  ? 'border-[var(--color-brand-yellow)] bg-amber-50'
                  : 'border-gray-200 hover:border-gray-400'
              }`}
            >
              {option.key}
            </button>
          ))}
        </div>
        <p className="mt-1 text-[11px] text-gray-400">
          Prints at {pointsFor(size, options.textSizes)}pt.
        </p>
      </div>

      <div>
        <Label className="text-xs text-gray-600">Alignment</Label>
        <div className="mt-1.5 flex gap-1.5">
          {options.alignments.map(option => {
            const Icon = ALIGN_ICONS[option];
            return (
              <button
                key={option}
                type="button"
                onClick={() => patch({ align: option })}
                title={option}
                className={`flex flex-1 items-center justify-center rounded-md border py-1.5 transition-colors ${
                  option === align
                    ? 'border-[var(--color-brand-yellow)] bg-amber-50'
                    : 'border-gray-200 hover:border-gray-400'
                }`}
              >
                {Icon ? <Icon className="h-4 w-4" /> : option}
              </button>
            );
          })}
        </div>
      </div>

      <div>
        <Label htmlFor="text-color" className="text-xs text-gray-600">
          Colour
        </Label>
        <div className="mt-1.5 flex items-center gap-2">
          <input
            id="text-color"
            type="color"
            value={color}
            onChange={event => patch({ color: event.target.value.toUpperCase() })}
            className="h-9 w-14 cursor-pointer rounded border border-gray-200 bg-white p-0.5"
          />
          <code className="text-xs text-gray-500">{color}</code>
          {placement.color && (
            <Button
              type="button"
              variant="ghost"
              size="sm"
              className="ml-auto h-7 gap-1 px-2 text-xs"
              // Dropping the key rather than writing the computed default keeps
              // the region following the template if its background changes.
              onClick={() => patch({ color: undefined })}
            >
              <RotateCcw className="h-3 w-3" />
              Default
            </Button>
          )}
        </div>
      </div>

      <p className="text-[11px] text-gray-400">
        {characters} / {options.textMaxLength} characters. Text that overflows its box is trimmed
        when printed.
      </p>
    </div>
  );
};
